import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../models/mamoul_op_report.dart';
import '../../services/mamoul_op_report_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'mamoul_widgets.dart';

/// يرسم خطوط التوقيع (كل خط = قائمة نقاط متتالية).
void paintMamoulStrokes(Canvas canvas, List<List<Offset>> strokes, {Color color = Colors.black, double width = 3.0}) {
  final line = Paint()
    ..color = color
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke;
  final dot = Paint()
    ..color = color
    ..style = PaintingStyle.fill;
  for (final s in strokes) {
    if (s.isEmpty) continue;
    if (s.length == 1) {
      canvas.drawCircle(s.first, width / 2, dot);
      continue;
    }
    final path = Path()..moveTo(s.first.dx, s.first.dy);
    for (var i = 1; i < s.length; i++) {
      path.lineTo(s[i].dx, s[i].dy);
    }
    canvas.drawPath(path, line);
  }
}

class _PadPainter extends CustomPainter {
  final List<List<Offset>> strokes;

  _PadPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) => paintMamoulStrokes(canvas, strokes);

  @override
  bool shouldRepaint(covariant _PadPainter oldDelegate) => true;
}

/// «التوقيع الجاهز»: توقّع المشغّلة (فاطمة) مرة واحدة بإصبعها، فيُحفظ ويظهر
/// تلقائيًا في كل تقرير تشغيل جديد باسمها، بلا توقيع في كل مرة. لمسؤول الإنتاج
/// ومدير النظام (القيد الملزم على السيرفر). التقارير القديمة تبقى بتوقيعها.
class MamoulSignatureScreen extends StatefulWidget {
  final MamoulOpConfig config;

  const MamoulSignatureScreen({super.key, required this.config});

  @override
  State<MamoulSignatureScreen> createState() => _MamoulSignatureScreenState();
}

class _MamoulSignatureScreenState extends State<MamoulSignatureScreen> {
  late final TextEditingController _name = TextEditingController(text: widget.config.defaultOperator);
  bool _makeDefault = true;
  final List<List<Offset>> _strokes = [];
  Size _padSize = Size.zero;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _isEmpty => _strokes.every((s) => s.isEmpty);

  Offset _clamp(Offset p) => Offset(
        math.min(math.max(p.dx, 0.0), _padSize.width),
        math.min(math.max(p.dy, 0.0), _padSize.height),
      );

  void _start(Offset p) => setState(() => _strokes.add(<Offset>[_clamp(p)]));

  void _addPoint(Offset p) {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.last.add(_clamp(p)));
  }

  void _clear() => setState(_strokes.clear);

  /// يحوّل التوقيع إلى PNG شفاف مقصوص على حدود الرسم (حتى يملأ خانة التوقيع في
  /// الورقة المطبوعة)، بدقة مضاعفة.
  Future<String?> _exportPng() async {
    if (_isEmpty) return null;
    var minX = double.infinity, minY = double.infinity, maxX = -double.infinity, maxY = -double.infinity;
    for (final s in _strokes) {
      for (final p in s) {
        minX = math.min(minX, p.dx);
        minY = math.min(minY, p.dy);
        maxX = math.max(maxX, p.dx);
        maxY = math.max(maxY, p.dy);
      }
    }
    const pad = 8.0;
    const scale = 2.0;
    final w = (maxX - minX) + pad * 2;
    final h = (maxY - minY) + pad * 2;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale);
    canvas.translate(pad - minX, pad - minY);
    paintMamoulStrokes(canvas, _strokes);
    final picture = recorder.endRecording();
    final image = await picture.toImage((w * scale).ceil(), (h * scale).ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    if (bytes == null) return null;
    return base64Encode(bytes.buffer.asUint8List());
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final name = _name.text.trim();
    if (name.isEmpty) {
      showMamoulSnack(context, 'اكتبي اسم صاحبة التوقيع', error: true);
      return;
    }
    if (_isEmpty) {
      showMamoulSnack(context, 'ارسمي التوقيع داخل المربع أولًا', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final png = await _exportPng();
      if (png == null) throw StateError('تعذّر تجهيز صورة التوقيع');
      await MamoulOpReportService.saveSignature(operatorName: name, pngBase64: png);
      if (_makeDefault) await MamoulOpReportService.setDefaultOperator(name);
      notifyMamoulOpChanged();
      if (!mounted) return;
      showMamoulSnack(context, 'حُفظ توقيع $name — سيظهر جاهزًا في التقارير الجديدة');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMamoulSnack(context, mamoulErrorText(e), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = widget.config.signature;
    return Scaffold(
      appBar: const ScreenTopBar(title: 'التوقيع الجاهز'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MamoulFieldLabel('اسم صاحبة التوقيع (Operate by)', required: true),
              MamoulTextField(controller: _name, hint: 'مثل: فاطمة', maxLength: 80),
              CheckboxListTile(
                value: _makeDefault,
                onChanged: _saving ? null : (v) => setState(() => _makeDefault = v ?? true),
                title: const Text('يُكتب هذا الاسم تلقائيًا في كل تقرير جديد', style: TextStyle(fontSize: 13)),
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                dense: true,
              ),
              if (current != null && current.png != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Text(
                        'المحفوظ حاليًا (${current.operatorName}):',
                        style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Image.memory(current.png!, height: 40, fit: BoxFit.contain),
                        ),
                      ),
                    ],
                  ),
                ),
              const Text(
                'تُوقّع صاحبة التوقيع بإصبعها داخل المربع الأبيض:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _padSize = Size(constraints.maxWidth, constraints.maxHeight);
                    return Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: _saving ? null : (e) => _start(e.localPosition),
                      onPointerMove: _saving ? null : (e) => _addPoint(e.localPosition),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: kMamoulColor.withOpacity(0.5), width: 1.5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(13),
                          child: Stack(
                            children: [
                              Positioned.fill(child: CustomPaint(painter: _PadPainter(_strokes))),
                              if (_isEmpty)
                                const Center(
                                  child: Text(
                                    'وقّعي هنا',
                                    style: TextStyle(fontSize: 15, color: AppColors.textFaint),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: MamoulOutlineButton(label: 'مسح', icon: Icons.refresh, onPressed: _saving ? null : _clear),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: PrimaryButton(
                      label: _saving ? 'جارٍ الحفظ…' : 'حفظ التوقيع',
                      color: kMamoulColor,
                      icon: Icons.check,
                      onPressed: _saving ? null : _save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/mamoul_monitor.dart';
import '../../services/mamoul_monitor_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'mamoul_output_widgets.dart';
import 'mamoul_widgets.dart';

/// عدّاد الإنتاج بالدقيقة (لكل مكينة).
///
/// الفني يشغّل مؤقّت دقيقة واحدة، ويعدّ القطع التي تخرج من المكينة، وعند انتهاء
/// المؤقّت يكتب العدد ثم ساعات عمل المكينة. يحسب التطبيق فورًا: الكيلو يخرج كل كم
/// ثانية، والإنتاج في الساعة، والإنتاج خلال ساعات العمل. زر «حفظ قراءة المكينة»
/// يحفظ القراءة، فتظهر تلقائيًا في بطاقة المكينة (التحليل ← مقارنة المكائن، وغرفة المكينة).
/// وزن القطعة لا يُسأل عنه: يأتي من أوزان عيّنات المكينة أو التشغيلة (أو ٦٫٢ افتراضيًا).
/// يعيد true عبر Navigator.pop بعد الحفظ.
class MamoulRateCounterSheet extends StatefulWidget {
  final String machineId;
  final String machineLabel;

  /// وزن القطعة بالجرام المحسوب عليه، ونص يشرح مصدره.
  final double defaultWeight;
  final String weightSource;

  /// ساعات العمل المقترحة (آخر قراءة للمكينة أو وقت بدء/انتهاء التشغيلة).
  final double? defaultHours;

  /// تشغيلة مرتبطة بالقراءة (اختياري).
  final String? runId;

  const MamoulRateCounterSheet({
    super.key,
    required this.machineId,
    required this.machineLabel,
    required this.defaultWeight,
    required this.weightSource,
    this.defaultHours,
    this.runId,
  });

  @override
  State<MamoulRateCounterSheet> createState() => _MamoulRateCounterSheetState();
}

enum _Phase { idle, running, finished }

/// ساعات عمل تشغيلة من وقتي البدء والانتهاء 'HH:MM' (تتجاوز منتصف الليل لو الانتهاء أصغر)،
/// أو null لو أحدهما غير مسجَّل.
double? mamoulRunHours(String? start, String? end) {
  int? toMin(String? s) {
    if (s == null) return null;
    final p = s.split(':');
    if (p.length < 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }

  final a = toMin(start);
  final b = toMin(end);
  if (a == null || b == null) return null;
  var diff = b - a;
  if (diff < 0) diff += 1440;
  if (diff <= 0) return null;
  return double.parse((diff / 60).toStringAsFixed(2));
}

class _MamoulRateCounterSheetState extends State<MamoulRateCounterSheet> {
  static const int _windowSeconds = 60;

  final TextEditingController _count = TextEditingController();
  final FocusNode _countFocus = FocusNode();
  final TextEditingController _hours = TextEditingController();

  Timer? _ticker;
  DateTime? _endAt;
  _Phase _phase = _Phase.idle;
  int _shownSeconds = _windowSeconds;
  int _remainingMs = _windowSeconds * 1000;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final h = widget.defaultHours;
    if (h != null && h > 0) {
      _hours.text = h == h.roundToDouble() ? h.toInt().toString() : h.toString();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _count.dispose();
    _countFocus.dispose();
    _hours.dispose();
    super.dispose();
  }

  // ------------------------------- المؤقّت -------------------------------

  void _start() {
    _ticker?.cancel();
    setState(() {
      _error = null;
      _phase = _Phase.running;
      _remainingMs = _windowSeconds * 1000;
      _shownSeconds = _windowSeconds;
      _endAt = DateTime.now().add(const Duration(seconds: _windowSeconds));
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
  }

  void _tick() {
    final end = _endAt;
    if (end == null || !mounted) return;
    final left = end.difference(DateTime.now()).inMilliseconds;
    if (left <= 0) {
      _ticker?.cancel();
      _ticker = null;
      setState(() {
        _remainingMs = 0;
        _shownSeconds = 0;
        _phase = _Phase.finished;
      });
      _alert();
      _countFocus.requestFocus();
      return;
    }
    final shown = (left + 999) ~/ 1000;
    _remainingMs = left;
    if (shown != _shownSeconds) {
      setState(() => _shownSeconds = shown);
    }
  }

  void _cancel() {
    _ticker?.cancel();
    _ticker = null;
    setState(() {
      _phase = _Phase.idle;
      _remainingMs = _windowSeconds * 1000;
      _shownSeconds = _windowSeconds;
      _endAt = null;
    });
  }

  /// اهتزاز (وصوت حيث يدعمه الجهاز) ثلاث مرات عند انتهاء الدقيقة.
  Future<void> _alert() async {
    for (var i = 0; i < 3; i++) {
      try {
        await HapticFeedback.vibrate();
        await SystemSound.play(SystemSoundType.alert);
      } catch (_) {
        // الأجهزة التي لا تدعم الاهتزاز/الصوت تكتفي بتغيّر الشاشة.
      }
      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
    }
  }

  // ------------------------------- القيم -------------------------------

  /// عدد القطع في الدقيقة، أو null لو الخانة فارغة/غير صالحة.
  double? get _ppm {
    final v = mamoulParseNumber(_count.text);
    if (v == null || !v.isFinite || v < 0.1 || v > 5000) return null;
    return v;
  }

  /// ساعات العمل، أو null لو الخانة فارغة/غير صالحة.
  double? get _hoursValue {
    final v = mamoulParseNumber(_hours.text);
    if (v == null || !v.isFinite || v < 0.1 || v > 24) return null;
    return v;
  }

  Future<void> _save() async {
    if (_saving) return;
    final ppm = _ppm;
    if (ppm == null) {
      setState(() => _error = 'اكتب عدد القطع التي عددتها خلال الدقيقة (رقم أكبر من صفر)');
      return;
    }
    if (_phase == _Phase.running) {
      setState(() => _error = 'انتظر حتى تنتهي الدقيقة ثم اكتب العدد');
      return;
    }
    if (_hours.text.trim().isNotEmpty && _hoursValue == null) {
      setState(() => _error = 'ساعات العمل غير صحيحة (من ٠٫١ إلى ٢٤)');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await MamoulMonitorService.addRateReading(
        widget.machineId,
        piecesPerMin: ppm,
        weightG: widget.defaultWeight,
        workHours: _hoursValue,
        runId: widget.runId,
      );
      notifyMamoulChanged();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = mamoulErrorText(err);
      });
    }
  }

  // ------------------------------- الواجهة -------------------------------

  String _clock(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return mamoulTimeLabel('${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}');
  }

  Widget _header() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(height: 14),
        Text('عدّاد الإنتاج — ${widget.machineLabel}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text(
          'اضغط «ابدأ» وعُدّ القطع التي تخرج من المكينة طوال دقيقة، ثم اكتب العدد وساعات عمل المكينة.',
          style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.5),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  Widget _timerCard() {
    final running = _phase == _Phase.running;
    final finished = _phase == _Phase.finished;
    final secs = finished ? 0 : (running ? _shownSeconds : _windowSeconds);
    final Color color = finished ? AppColors.successText : (running ? kMamoulColor : AppColors.textSecondary);
    final double progress = finished ? 1.0 : (running ? 1 - (_remainingMs / (_windowSeconds * 1000)) : 0.0);
    final String hint = finished
        ? 'انتهت الدقيقة — اكتب عدد القطع التي عددتها'
        : (running ? 'عُدّ القطع الآن...' : 'اضغط «ابدأ العدّ» ثم عُدّ القطع التي تخرج من المكينة');

    return MamoulCard(
      borderColor: finished ? AppColors.successText : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Text(
              _clock(secs),
              textDirection: TextDirection.ltr,
              style: TextStyle(fontSize: 54, fontWeight: FontWeight.bold, color: color),
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0).toDouble(),
              minHeight: 8,
              color: color,
              backgroundColor: AppColors.divider,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hint,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: finished ? AppColors.successText : AppColors.textMuted, height: 1.5),
          ),
          const SizedBox(height: 12),
          if (_phase == _Phase.idle)
            PrimaryButton(label: 'ابدأ العدّ (دقيقة واحدة)', color: kMamoulColor, icon: Icons.play_arrow, onPressed: _start)
          else if (running)
            MamoulOutlineButton(label: 'إلغاء', icon: Icons.stop, color: kMamoulDanger, onPressed: _cancel)
          else
            MamoulOutlineButton(label: 'إعادة الدقيقة', icon: Icons.replay, onPressed: _start),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ppm = _ppm;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(),
        _timerCard(),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const MamoulFieldLabel('عدد القطع في الدقيقة'),
                  TextField(
                    controller: _count,
                    focusNode: _countFocus,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.right,
                    onChanged: (_) => setState(() => _error = null),
                    decoration: fieldDecoration(hint: 'مثال: ١٢٠'),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const MamoulFieldLabel('ساعات عمل المكينة'),
                  MamoulNumberField(controller: _hours, hint: 'مثال: ٨', onChanged: (_) => setState(() => _error = null)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'محسوب على وزن القطعة ${mamoulNum(widget.defaultWeight)} جم — ${widget.weightSource}.',
          style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.5),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(fontSize: 13, color: kMamoulDanger, height: 1.5)),
        ],
        const SizedBox(height: 14),
        if (ppm == null)
          const InfoNote(
            text: 'بعد انتهاء الدقيقة اكتب عدد القطع، وستظهر هنا كم تنتج المكينة.',
            color: AppColors.textMuted,
            icon: Icons.hourglass_empty,
          )
        else
          MamoulCard(
            child: MamoulOutputTiles(piecesPerMin: ppm, weightG: widget.defaultWeight, workHours: _hoursValue),
          ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: _saving ? 'جارٍ الحفظ...' : 'حفظ قراءة المكينة',
          color: kMamoulColor,
          icon: Icons.check,
          onPressed: (_saving || ppm == null) ? null : _save,
        ),
        const SizedBox(height: 4),
        const Text(
          'تظهر القراءة المحفوظة تلقائيًا في بطاقة المكينة: «التحليل» ← «مقارنة بين المكائن»، وفي غرفة المكينة.',
          style: TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.5),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('إغلاق')),
      ],
    );
  }
}

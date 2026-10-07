import 'package:flutter/material.dart';

import '../../models/mamoul_monitor.dart';
import '../../services/mamoul_monitor_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'mamoul_widgets.dart';

/// النوافذ السفلية الخاصة بتشغيلة المعمول: إضافة/تعديل عيّنة أوزان، تغيير
/// السرعات، تسجيل عيوب، وإغلاق التشغيلة. كلها تحفظ بنفسها عبر
/// [MamoulMonitorService] وتستدعي [notifyMamoulChanged] ثم تغلق بـ true.

/// عنوان النافذة السفلية مع مقبض صغير.
class _SheetHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SheetHeader({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
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
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.5)),
        ],
        const SizedBox(height: 14),
      ],
    );
  }
}

String? _nullIfBlank(String s) {
  final t = s.trim();
  return t.isEmpty ? null : t;
}

/// رقم عشري كنص لاتيني بلا أصفار زائدة (لتعبئة حقول التعديل).
String mamoulPlainNumber(double? v) {
  if (v == null) return '';
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toString();
}

// ---------------------------------------------------------------------------
// عيّنة أوزان
// ---------------------------------------------------------------------------

/// إضافة عيّنة أوزان جديدة، أو تعديل [existing]. تُدخل أوزان القطع المقاسة
/// بالميزان (واحدة بعد أخرى أو عدة أرقام تفصلها مسافة) ويظهر الحكم فورًا.
class MamoulSampleSheet extends StatefulWidget {
  final MamoulRun run;
  final MamoulSample? existing;

  const MamoulSampleSheet({super.key, required this.run, this.existing});

  @override
  State<MamoulSampleSheet> createState() => _MamoulSampleSheetState();
}

class _MamoulSampleSheetState extends State<MamoulSampleSheet> {
  final TextEditingController _input = TextEditingController();
  final TextEditingController _note = TextEditingController();
  final List<double> _weights = <double>[];
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _weights.addAll(e.weights);
      _note.text = e.note ?? '';
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _note.dispose();
    super.dispose();
  }

  /// يقرأ ما كُتب في الحقل (رقم أو عدة أرقام بمسافات) ويضيفه للقائمة.
  /// يعيد false لو في النص قيمة غير صالحة (فلا يضيف شيئًا).
  bool _addFromInput() {
    final raw = _input.text.trim();
    if (raw.isEmpty) return true;
    final parts = raw.split(RegExp(r'\s+'));
    final parsed = <double>[];
    for (final p in parts) {
      final v = mamoulParseNumber(p);
      if (v == null || v < 0.1 || v > 500) {
        setState(() => _error = '«$p» ليس وزنًا صحيحًا — اكتب الوزن بالجرام مثل ٦٫٢');
        return false;
      }
      parsed.add(v);
    }
    if (_weights.length + parsed.length > 100) {
      setState(() => _error = 'الحد الأقصى ١٠٠ قطعة في العيّنة الواحدة');
      return false;
    }
    setState(() {
      _weights.addAll(parsed);
      _input.clear();
      _error = null;
    });
    return true;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_addFromInput()) return;
    if (_weights.isEmpty) {
      setState(() => _error = 'أدخل وزن قطعة واحدة على الأقل');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final note = _nullIfBlank(_note.text);
      final e = widget.existing;
      if (e == null) {
        await MamoulMonitorService.addSample(widget.run.id, weights: List<double>.from(_weights), note: note);
      } else {
        await MamoulMonitorService.updateSample(e.id, weights: List<double>.from(_weights), note: note);
      }
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

  @override
  Widget build(BuildContext context) {
    final run = widget.run;
    final stats = mamoulLocalStats(_weights, min: run.weightMin, max: run.weightMax, target: run.targetWeight);
    final hint = mamoulTrendHint(stats.trend);
    final editing = widget.existing != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SheetHeader(
          title: editing ? 'تعديل العيّنة' : 'إضافة عيّنة أوزان',
          subtitle:
              'ضع القطع على الميزان واكتب وزن كل قطعة بالجرام. النطاق المقبول من ${mamoulNum(run.weightMin)} إلى ${mamoulNum(run.weightMax)}.',
        ),
        Row(
          children: [
            Expanded(
              child: MamoulNumberField(
                controller: _input,
                hint: 'وزن القطعة (جرام)',
                onSubmitted: (_) => _addFromInput(),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: _saving ? null : _addFromInput,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kMamoulColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                ),
                child: const Text('إضافة', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          'يمكنك كتابة عدة أوزان معًا تفصل بينها مسافة، مثل: ٦٫٢ ٦٫١ ٦٫٣',
          style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        if (_weights.isEmpty)
          const Text('لم تُضف أوزان بعد', style: TextStyle(fontSize: 13, color: AppColors.textFaint))
        else ...[
          MamoulWeightChips(
            weights: _weights,
            min: run.weightMin,
            max: run.weightMax,
            onRemove: (i) => setState(() => _weights.removeAt(i)),
          ),
          const SizedBox(height: 4),
          const Text('اضغط على أي وزن لحذفه', style: TextStyle(fontSize: 11, color: AppColors.textFaint)),
          const SizedBox(height: 12),
          MamoulCard(
            borderColor: mamoulLevelColor(stats.level).withOpacity(0.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    MamoulLevelPill(level: stats.level),
                    const Spacer(),
                    Text('${mamoulCount(stats.count)} قطعة', style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 22,
                  runSpacing: 8,
                  children: [
                    MamoulStat(label: 'المتوسط', value: mamoulWeight(stats.avg), color: mamoulLevelColor(stats.level)),
                    MamoulStat(label: 'الأقل', value: mamoulWeight(stats.min)),
                    MamoulStat(label: 'الأعلى', value: mamoulWeight(stats.max)),
                    MamoulStat(
                      label: 'خارج النطاق',
                      value: stats.outCount == 0 ? '٠' : '${mamoulCount(stats.outCount)} (${mamoulPct(stats.outPct)})',
                      color: stats.outCount == 0 ? null : kMamoulDanger,
                    ),
                  ],
                ),
                if (hint != null) ...[
                  const SizedBox(height: 10),
                  Text(hint, style: const TextStyle(fontSize: 12.5, color: AppColors.warningText, height: 1.5)),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        MamoulTextField(controller: _note, hint: 'ملاحظة على العيّنة (اختياري)', maxLength: 300),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(fontSize: 13, color: kMamoulDanger, height: 1.5)),
        ],
        const SizedBox(height: 14),
        PrimaryButton(
          label: _saving ? 'جارٍ الحفظ...' : (editing ? 'حفظ التعديل' : 'حفظ العيّنة'),
          color: kMamoulColor,
          icon: Icons.check,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// تغيير السرعات
// ---------------------------------------------------------------------------

/// تغيير سرعات المحركات الثلاثة أثناء التشغيل. تُسجَّل في سجل التغييرات،
/// وتُنسَخ السرعات الجديدة تلقائيًا على كل عيّنة تؤخذ بعدها.
class MamoulSpeedSheet extends StatefulWidget {
  final MamoulRun run;

  const MamoulSpeedSheet({super.key, required this.run});

  @override
  State<MamoulSpeedSheet> createState() => _MamoulSpeedSheetState();
}

class _MamoulSpeedSheetState extends State<MamoulSpeedSheet> {
  late final TextEditingController _belt;
  late final TextEditingController _push;
  late final TextEditingController _rotary;
  final TextEditingController _reason = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _belt = TextEditingController(text: mamoulPlainNumber(widget.run.speedBelt));
    _push = TextEditingController(text: mamoulPlainNumber(widget.run.speedPush));
    _rotary = TextEditingController(text: mamoulPlainNumber(widget.run.speedRotary));
  }

  @override
  void dispose() {
    _belt.dispose();
    _push.dispose();
    _rotary.dispose();
    _reason.dispose();
    super.dispose();
  }

  /// null = الحقل فارغ (يبقى كما هو)، وإلا الرقم. يرمي FormatException لو غير صالح.
  double? _read(TextEditingController c, String label) {
    final raw = c.text.trim();
    if (raw.isEmpty) return null;
    final v = mamoulParseNumber(raw);
    if (v == null || v < 0 || v > 100000) {
      throw FormatException('سرعة $label غير صحيحة');
    }
    return v;
  }

  Future<void> _save() async {
    if (_saving) return;
    double? belt;
    double? push;
    double? rotary;
    try {
      belt = _read(_belt, 'السير');
      push = _read(_push, 'الدفع');
      rotary = _read(_rotary, 'الدوار');
    } on FormatException catch (e) {
      setState(() => _error = e.message);
      return;
    }
    final run = widget.run;
    final changed = belt != run.speedBelt || push != run.speedPush || rotary != run.speedRotary;
    if (!changed) {
      setState(() => _error = 'لم تغيّر أي سرعة');
      return;
    }
    if (belt == null && push == null && rotary == null) {
      setState(() => _error = 'أدخل سرعة واحدة على الأقل');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await MamoulMonitorService.changeSpeeds(
        run.id,
        belt: belt,
        push: push,
        rotary: rotary,
        reason: _nullIfBlank(_reason.text),
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

  Widget _field(String label, TextEditingController c) {
    final unit = mamoulUnitLabel(widget.run.speedUnit);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MamoulFieldLabel('$label ($unit)'),
        MamoulNumberField(controller: c, hint: 'اقرأ الرقم من الشاشة'),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SheetHeader(
          title: 'تغيير السرعات',
          subtitle: 'اكتب السرعات كما تظهر الآن على شاشات المحركات. السرعات الجديدة تُسجَّل على كل عيّنة تؤخذ بعد هذا التغيير.',
        ),
        _field('سرعة السير', _belt),
        _field('سرعة دفع المعمول', _push),
        _field('سرعة الدوار (التكوير)', _rotary),
        const MamoulFieldLabel('سبب التغيير (اختياري)'),
        MamoulTextField(controller: _reason, hint: 'مثال: الأوزان تميل للزيادة', maxLength: 300),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(fontSize: 13, color: kMamoulDanger, height: 1.5)),
        ],
        const SizedBox(height: 14),
        PrimaryButton(
          label: _saving ? 'جارٍ الحفظ...' : 'حفظ السرعات الجديدة',
          color: kMamoulColor,
          icon: Icons.speed,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// العيوب
// ---------------------------------------------------------------------------

/// عدّاد بزرّي + و−.
class _CountStepper extends StatelessWidget {
  final String label;
  final String hint;
  final int value;
  final ValueChanged<int> onChanged;

  const _CountStepper({required this.label, required this.hint, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                Text(hint, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'نقص',
            onPressed: value > 0 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
            color: kMamoulColor,
          ),
          SizedBox(
            width: 34,
            child: Text(
              mamoulCount(value),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            tooltip: 'زيادة',
            onPressed: value < 100000 ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline),
            color: kMamoulColor,
          ),
        ],
      ),
    );
  }
}

/// تسجيل عيوب لوحظت على الخط: توائم (قطعتان ملتصقتان)، زوائد، ومرفوض.
class MamoulDefectSheet extends StatefulWidget {
  final MamoulRun run;

  const MamoulDefectSheet({super.key, required this.run});

  @override
  State<MamoulDefectSheet> createState() => _MamoulDefectSheetState();
}

class _MamoulDefectSheetState extends State<MamoulDefectSheet> {
  int _twins = 0;
  int _flash = 0;
  int _rejected = 0;
  final TextEditingController _note = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_twins + _flash + _rejected == 0) {
      setState(() => _error = 'زد عددًا واحدًا على الأقل');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await MamoulMonitorService.addDefects(
        widget.run.id,
        twins: _twins,
        flash: _flash,
        rejected: _rejected,
        note: _nullIfBlank(_note.text),
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SheetHeader(
          title: 'تسجيل عيوب',
          subtitle: 'اكتب عدد القطع المعيبة التي رأيتها منذ آخر تسجيل (لا تكرّر ما سجّلته من قبل).',
        ),
        _CountStepper(label: 'توائم', hint: 'قطعتان ملتصقتان معًا', value: _twins, onChanged: (v) => setState(() => _twins = v)),
        _CountStepper(label: 'زوائد', hint: 'قطع بزيادة أو بروز زائد', value: _flash, onChanged: (v) => setState(() => _flash = v)),
        _CountStepper(label: 'مرفوض', hint: 'قطع مرفوضة لأي سبب آخر', value: _rejected, onChanged: (v) => setState(() => _rejected = v)),
        const SizedBox(height: 4),
        MamoulTextField(controller: _note, hint: 'ملاحظة (اختياري)', maxLength: 300),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(fontSize: 13, color: kMamoulDanger, height: 1.5)),
        ],
        const SizedBox(height: 14),
        PrimaryButton(
          label: _saving ? 'جارٍ الحفظ...' : 'حفظ العيوب',
          color: kMamoulColor,
          icon: Icons.check,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// إغلاق التشغيلة
// ---------------------------------------------------------------------------

/// إغلاق التشغيلة: وقت الانتهاء وعدد المعمول المنتَج (يُستخدم لحساب نسبة العيوب).
class MamoulCloseSheet extends StatefulWidget {
  final MamoulRun run;

  const MamoulCloseSheet({super.key, required this.run});

  @override
  State<MamoulCloseSheet> createState() => _MamoulCloseSheetState();
}

class _MamoulCloseSheetState extends State<MamoulCloseSheet> {
  late TimeOfDay _end;
  late final TextEditingController _produced;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _end = mamoulParseTime(widget.run.endTime) ?? TimeOfDay.now();
    _produced = TextEditingController(
      text: widget.run.producedCount == null ? '' : widget.run.producedCount.toString(),
    );
  }

  @override
  void dispose() {
    _produced.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _end);
    if (t != null) setState(() => _end = t);
  }

  Future<void> _save() async {
    if (_saving) return;
    int? produced;
    final raw = _produced.text.trim();
    if (raw.isNotEmpty) {
      final v = mamoulParseNumber(raw);
      if (v == null || v < 0 || v != v.roundToDouble() || v > 1000000) {
        setState(() => _error = 'عدد المنتَج يجب أن يكون رقمًا صحيحًا');
        return;
      }
      produced = v.toInt();
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await MamoulMonitorService.closeRun(widget.run.id, endTime: mamoulTimeOf(_end), producedCount: produced);
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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _SheetHeader(
          title: 'إغلاق التشغيلة',
          subtitle: 'بعد الإغلاق لا يمكن إضافة عيّنات أو عيوب إلا بإعادة فتحها.',
        ),
        const MamoulFieldLabel('وقت الانتهاء'),
        MamoulPickerField(
          text: mamoulTimeLabel(mamoulTimeOf(_end)),
          hint: 'اختر الوقت',
          icon: Icons.access_time,
          onTap: _pickTime,
        ),
        const SizedBox(height: 12),
        const MamoulFieldLabel('عدد المعمول المنتَج في التشغيلة (اختياري)'),
        MamoulNumberField(controller: _produced, hint: 'مثال: ١٢٠٠٠', decimal: false),
        const SizedBox(height: 4),
        const Text(
          'يُستخدم لحساب نسبة العيوب من الإنتاج الكلي.',
          style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(fontSize: 13, color: kMamoulDanger, height: 1.5)),
        ],
        const SizedBox(height: 14),
        PrimaryButton(
          label: _saving ? 'جارٍ الإغلاق...' : 'إغلاق التشغيلة',
          color: kMamoulColor,
          icon: Icons.lock_outline,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/mamoul_monitor.dart';
import '../../services/auth_service.dart';
import '../../services/mamoul_monitor_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'mamoul_machine_sheet.dart';
import 'mamoul_run_sheets.dart' show mamoulPlainNumber;
import 'mamoul_widgets.dart';

/// نموذج تشغيلة جديدة، أو تعديل بيانات [existing] (السرعات تُغيَّر من شاشة
/// التشغيلة نفسها لا من هنا). عند الحفظ يُغلق النموذج ويعيد معرّف التشغيلة.
class MamoulRunFormScreen extends StatefulWidget {
  final MamoulRun? existing;
  final DateTime? initialDate;
  final String? initialMachineId;

  const MamoulRunFormScreen({super.key, this.existing, this.initialDate, this.initialMachineId});

  @override
  State<MamoulRunFormScreen> createState() => _MamoulRunFormScreenState();
}

class _MamoulRunFormScreenState extends State<MamoulRunFormScreen> {
  String? _machineId;
  late DateTime _date;
  double _target = kMamoulTargets.first;
  String? _shift;
  TimeOfDay? _startTime;
  String _unit = 'Hz';
  String? _moisture;

  final TextEditingController _operator = TextEditingController();
  final TextEditingController _batch = TextEditingController();
  final TextEditingController _moisturePct = TextEditingController();
  final TextEditingController _belt = TextEditingController();
  final TextEditingController _push = TextEditingController();
  final TextEditingController _rotary = TextEditingController();
  final TextEditingController _produced = TextEditingController();
  final TextEditingController _notes = TextEditingController();

  bool _saving = false;
  bool _machinesLoading = true;
  String? _machinesError;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _machineId = e.machineId;
      _date = mamoulParseDate(e.runDate) ?? DateTime.now();
      _target = e.targetWeight;
      _shift = e.shift;
      _startTime = mamoulParseTime(e.startTime);
      _unit = e.speedUnit;
      _moisture = e.moistureLevel;
      _operator.text = e.operatorName ?? '';
      _batch.text = e.pasteBatch ?? '';
      _moisturePct.text = mamoulPlainNumber(e.moisturePct);
      _produced.text = e.producedCount == null ? '' : e.producedCount.toString();
      _notes.text = e.notes ?? '';
    } else {
      final d = widget.initialDate ?? DateTime.now();
      _date = DateTime(d.year, d.month, d.day);
      _machineId = widget.initialMachineId;
      _startTime = TimeOfDay.now();
      final user = context.read<AuthService>().currentUser;
      _operator.text = user?.name ?? '';
    }
    _loadMachines();
  }

  @override
  void dispose() {
    _operator.dispose();
    _batch.dispose();
    _moisturePct.dispose();
    _belt.dispose();
    _push.dispose();
    _rotary.dispose();
    _produced.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadMachines() async {
    setState(() {
      _machinesLoading = true;
      _machinesError = null;
    });
    final err = await reloadMamoulMachines();
    if (!mounted) return;
    setState(() {
      _machinesLoading = false;
      _machinesError = err;
      // لو لا مكينة مختارة ويوجد خيار واحد فقط فاختره تلقائيًا.
      if (_machineId == null) {
        final active = mamoulActiveMachines();
        if (active.length == 1) _machineId = active.first.id;
      }
    });
  }

  /// خيارات المكينة: المفعّلة + مكينة التشغيلة الحالية لو معطّلة (عند التعديل).
  List<MamoulMachine> _machineOptions() {
    final all = mamoulMachines.value;
    return all.where((m) => m.active || m.id == _machineId).toList();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _startTime ?? TimeOfDay.now());
    if (t != null) setState(() => _startTime = t);
  }

  /// يقرأ رقمًا اختياريًا: فارغ → null، غير صالح → يرمي FormatException بالرسالة.
  double? _readNumber(TextEditingController c, String label, {double max = 100000}) {
    final raw = c.text.trim();
    if (raw.isEmpty) return null;
    final v = mamoulParseNumber(raw);
    if (v == null || v < 0 || v > max) throw FormatException('$label غير صحيح');
    return v;
  }

  String? _nullIfBlank(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _save() async {
    if (_saving) return;
    final machineId = _machineId;
    if (machineId == null) {
      showMamoulSnack(context, 'اختر المكينة أولًا', error: true);
      return;
    }
    double? belt;
    double? push;
    double? rotary;
    double? pct;
    int? produced;
    try {
      belt = _readNumber(_belt, 'سرعة السير');
      push = _readNumber(_push, 'سرعة الدفع');
      rotary = _readNumber(_rotary, 'سرعة الدوار');
      pct = _readNumber(_moisturePct, 'نسبة الرطوبة', max: 100);
      final p = _readNumber(_produced, 'عدد المنتَج', max: 1000000);
      if (p != null) {
        if (p != p.roundToDouble()) throw const FormatException('عدد المنتَج يجب أن يكون رقمًا صحيحًا');
        produced = p.toInt();
      }
    } on FormatException catch (e) {
      showMamoulSnack(context, e.message, error: true);
      return;
    }

    setState(() => _saving = true);
    try {
      final startText = _startTime == null ? null : mamoulTimeOf(_startTime!);
      final String runId;
      final existing = widget.existing;
      if (existing == null) {
        final detail = await MamoulMonitorService.createRun(
          machineId: machineId,
          runDate: mamoulIsoDate(_date),
          targetWeight: _target,
          shift: _shift,
          startTime: startText,
          operatorName: _nullIfBlank(_operator.text),
          pasteBatch: _nullIfBlank(_batch.text),
          moistureLevel: _moisture,
          moisturePct: pct,
          speedUnit: _unit,
          speedBelt: belt,
          speedPush: push,
          speedRotary: rotary,
          notes: _nullIfBlank(_notes.text),
        );
        runId = detail.run.id;
      } else {
        final detail = await MamoulMonitorService.updateRun(
          existing.id,
          machineId: machineId,
          runDate: mamoulIsoDate(_date),
          targetWeight: _target,
          shift: _shift,
          startTime: startText,
          operatorName: _nullIfBlank(_operator.text),
          pasteBatch: _nullIfBlank(_batch.text),
          moistureLevel: _moisture,
          moisturePct: pct,
          speedUnit: _unit,
          producedCount: produced,
          notes: _nullIfBlank(_notes.text),
        );
        runId = detail.run.id;
      }
      notifyMamoulChanged();
      if (!mounted) return;
      Navigator.of(context).pop(runId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMamoulSnack(context, mamoulErrorText(e), error: true);
    }
  }

  // ------------------------------- بناء الواجهة -------------------------------

  Widget _machineSection() {
    if (_machinesLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: kMamoulColor))),
      );
    }
    if (_machinesError != null) {
      return MamoulErrorView(message: _machinesError!, onRetry: _loadMachines);
    }
    final options = _machineOptions();
    if (options.isEmpty) {
      final role = context.read<AuthService>().currentUser?.role;
      final canManage = role != null && canManageMaintenance(role);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InfoNote(
            text: 'لا توجد مكائن مضافة بعد. يجب إضافة مكينة واحدة على الأقل قبل تسجيل أي تشغيلة.',
            color: AppColors.warningText,
            icon: Icons.info_outline,
          ),
          if (canManage) ...[
            const SizedBox(height: 10),
            MamoulOutlineButton(
              label: 'إضافة مكينة',
              icon: Icons.add,
              onPressed: () async {
                final added = await showAddMamoulMachineSheet(context);
                if (added != null && mounted) {
                  setState(() => _machineId = added.id);
                }
              },
            ),
          ] else
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'اطلب من مسؤول الصيانة إضافة المكينة من زر «المكائن» أعلى الشاشة الرئيسية للتبويب.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.5),
              ),
            ),
        ],
      );
    }
    return MamoulMachineChips(
      machines: options,
      selectedId: _machineId,
      allowAll: false,
      onChanged: (id) => setState(() => _machineId = id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final targets = <double>[...kMamoulTargets];
    if (!targets.contains(_target)) targets.add(_target);

    return Scaffold(
      appBar: ScreenTopBar(title: _editing ? 'تعديل التشغيلة' : 'تشغيلة معمول جديدة'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const MamoulFieldLabel('المكينة', required: true),
            _machineSection(),
            const SizedBox(height: 16),
            const MamoulFieldLabel('التاريخ', required: true),
            MamoulPickerField(
              text: '${mamoulWeekdayName(_date)} ${mamoulDateLabel(mamoulIsoDate(_date))}',
              hint: 'اختر التاريخ',
              icon: Icons.calendar_today_outlined,
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),
            const MamoulFieldLabel('الوزن المستهدف (جرام)', required: true),
            MamoulChoiceRow<double>(
              options: targets,
              labelOf: (v) => mamoulNum(v),
              selected: _target,
              onSelected: (v) => setState(() => _target = v),
            ),
            const SizedBox(height: 4),
            Text(
              'النطاق المقبول دائمًا من ${mamoulNum(kMamoulWeightMin)} إلى ${mamoulNum(kMamoulWeightMax)} جرام.',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            const MamoulFieldLabel('الوردية'),
            MamoulChoiceRow<String>(
              options: kMamoulShifts,
              labelOf: (v) => v,
              selected: _shift,
              onSelected: (v) => setState(() => _shift = v == _shift ? null : v),
            ),
            const SizedBox(height: 16),
            const MamoulFieldLabel('وقت البدء'),
            MamoulPickerField(
              text: _startTime == null ? '' : mamoulTimeLabel(mamoulTimeOf(_startTime!)),
              hint: 'اختر الوقت',
              icon: Icons.access_time,
              onTap: _pickTime,
              onClear: () => setState(() => _startTime = null),
            ),
            const SizedBox(height: 16),
            const MamoulFieldLabel('اسم المشغّل'),
            MamoulTextField(controller: _operator, hint: 'من يشغّل المكينة', maxLength: 120),
            const SizedBox(height: 16),
            const MamoulFieldLabel('دفعة العجينة'),
            MamoulTextField(controller: _batch, hint: 'رقم أو اسم دفعة العجينة', maxLength: 80),
            const SizedBox(height: 16),
            const MamoulFieldLabel('رطوبة العجينة'),
            MamoulChoiceRow<String>(
              options: const ['dry', 'medium', 'wet'],
              labelOf: mamoulMoistureLabel,
              selected: _moisture,
              onSelected: (v) => setState(() => _moisture = v == _moisture ? null : v),
            ),
            const SizedBox(height: 10),
            MamoulNumberField(controller: _moisturePct, hint: 'نسبة الرطوبة ٪ (اختياري، لو قسناها)'),
            const SizedBox(height: 18),
            const Divider(),
            const SizedBox(height: 10),
            const Text('سرعات المحركات', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              _editing
                  ? 'لتغيير السرعات أثناء التشغيل استخدم زر «تغيير السرعات» في شاشة التشغيلة (ليبقى سجل التغييرات).'
                  : 'اكتب الأرقام كما تظهر على الشاشات. ما تتركه فارغًا يُسجَّل بلا قيمة.',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.5),
            ),
            const SizedBox(height: 12),
            const MamoulFieldLabel('وحدة السرعة', required: true),
            MamoulChoiceRow<String>(
              options: kMamoulSpeedUnits,
              labelOf: mamoulUnitLabel,
              selected: _unit,
              onSelected: (v) => setState(() => _unit = v),
            ),
            if (!_editing) ...[
              const SizedBox(height: 14),
              const MamoulFieldLabel('سرعة السير'),
              MamoulNumberField(controller: _belt, hint: 'السير'),
              const SizedBox(height: 12),
              const MamoulFieldLabel('سرعة دفع المعمول'),
              MamoulNumberField(controller: _push, hint: 'الدفع'),
              const SizedBox(height: 12),
              const MamoulFieldLabel('سرعة الدوار (التكوير)'),
              MamoulNumberField(controller: _rotary, hint: 'الدوار'),
            ],
            if (_editing) ...[
              const SizedBox(height: 16),
              const MamoulFieldLabel('عدد المعمول المنتَج'),
              MamoulNumberField(controller: _produced, hint: 'يُستخدم لحساب نسبة العيوب', decimal: false),
            ],
            const SizedBox(height: 16),
            const MamoulFieldLabel('ملاحظات'),
            MamoulTextField(controller: _notes, hint: 'أي ملاحظة على التشغيلة', maxLines: 3, maxLength: 1000),
            const SizedBox(height: 22),
            PrimaryButton(
              label: _saving ? 'جارٍ الحفظ...' : (_editing ? 'حفظ التعديلات' : 'بدء التشغيلة'),
              color: kMamoulColor,
              icon: Icons.check,
              onPressed: _saving || _machinesLoading ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

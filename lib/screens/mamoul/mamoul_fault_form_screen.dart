import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/mamoul_monitor.dart';
import '../../services/auth_service.dart';
import '../../services/mamoul_monitor_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'mamoul_widgets.dart';

const List<String> _kComponents = ['piston', 'sensor', 'motor_belt', 'motor_push', 'motor_rotary', 'other'];

/// نموذج تسجيل عطل (بستون/حساس/محرك/أخرى) على مكينة، أو تعديل [existing].
/// مرّر [run] لتسجيل العطل على تشغيلة بعينها (تُؤخذ مكينتها منها)، أو
/// [initialMachineId] لتحديد المكينة مسبقًا. الحذف لمسؤول الصيانة ومدير النظام.
class MamoulFaultFormScreen extends StatefulWidget {
  final MamoulFault? existing;
  final MamoulRun? run;
  final String? initialMachineId;

  const MamoulFaultFormScreen({super.key, this.existing, this.run, this.initialMachineId});

  @override
  State<MamoulFaultFormScreen> createState() => _MamoulFaultFormScreenState();
}

class _MamoulFaultFormScreenState extends State<MamoulFaultFormScreen> {
  String? _machineId;
  String _component = 'piston';
  late DateTime _date;
  TimeOfDay? _time;
  String _status = 'open';

  final TextEditingController _part = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _downtime = TextEditingController();
  final TextEditingController _action = TextEditingController();

  bool _saving = false;
  bool _machinesLoading = true;
  String? _machinesError;

  bool get _editing => widget.existing != null;

  /// المكينة مقفلة لو العطل مرتبط بتشغيلة لها مكينة (حتى لا تتعارض بياناتهما).
  bool get _machineLocked {
    final e = widget.existing;
    if (e != null) return e.runId != null && e.machineId != null;
    final r = widget.run;
    return r != null && r.machineId != null;
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _machineId = e.machineId;
      _component = _kComponents.contains(e.component) ? e.component : 'other';
      _date = mamoulParseDate(e.date) ?? DateTime.now();
      _time = mamoulParseTime(e.time);
      _status = e.status;
      _part.text = e.partLabel ?? '';
      _description.text = e.description;
      _downtime.text = e.downtimeMinutes == null ? '' : e.downtimeMinutes.toString();
      _action.text = e.actionTaken ?? '';
    } else {
      final r = widget.run;
      _machineId = r?.machineId ?? widget.initialMachineId;
      final now = DateTime.now();
      _date = DateTime(now.year, now.month, now.day);
      _time = TimeOfDay.now();
    }
    _loadMachines();
  }

  @override
  void dispose() {
    _part.dispose();
    _description.dispose();
    _downtime.dispose();
    _action.dispose();
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
      if (_machineId == null) {
        final active = mamoulActiveMachines();
        if (active.length == 1) _machineId = active.first.id;
      }
    });
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
    final t = await showTimePicker(context: context, initialTime: _time ?? TimeOfDay.now());
    if (t != null) setState(() => _time = t);
  }

  String? _nullIfBlank(String s) {
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _save() async {
    if (_saving) return;
    final machineId = _machineId;
    if (machineId == null) {
      showMamoulSnack(context, 'اختر المكينة المعطّلة', error: true);
      return;
    }
    final description = _description.text.trim();
    if (description.isEmpty) {
      showMamoulSnack(context, 'اكتب وصفًا للعطل', error: true);
      return;
    }
    int? downtime;
    final rawDowntime = _downtime.text.trim();
    if (rawDowntime.isNotEmpty) {
      final v = mamoulParseNumber(rawDowntime);
      if (v == null || v < 0 || v != v.roundToDouble() || v > 100000) {
        showMamoulSnack(context, 'مدة التوقف تُكتب بالدقائق كرقم صحيح', error: true);
        return;
      }
      downtime = v.toInt();
    }

    setState(() => _saving = true);
    try {
      final timeText = _time == null ? null : mamoulTimeOf(_time!);
      final existing = widget.existing;
      if (existing == null) {
        await MamoulMonitorService.addFault(
          machineId: machineId,
          component: _component,
          partLabel: _nullIfBlank(_part.text),
          description: description,
          faultDate: mamoulIsoDate(_date),
          faultTime: timeText,
          downtimeMinutes: downtime,
          actionTaken: _nullIfBlank(_action.text),
          runId: widget.run?.id,
        );
      } else {
        await MamoulMonitorService.updateFault(
          existing.id,
          machineId: machineId,
          component: _component,
          partLabel: _nullIfBlank(_part.text),
          description: description,
          faultDate: mamoulIsoDate(_date),
          faultTime: timeText,
          downtimeMinutes: downtime,
          actionTaken: _nullIfBlank(_action.text),
          status: _status,
        );
      }
      notifyMamoulChanged();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMamoulSnack(context, mamoulErrorText(e), error: true);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null) return;
    final ok = await confirmMamoul(
      context,
      title: 'حذف العطل؟',
      message: 'سيُحذف سجل العطل «${existing.title}» نهائيًا.',
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    try {
      await MamoulMonitorService.deleteFault(existing.id);
      notifyMamoulChanged();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMamoulSnack(context, mamoulErrorText(e), error: true);
    }
  }

  Widget _machineSection() {
    if (_machineLocked) {
      final name = widget.existing?.machineName ?? widget.run?.machineLabel ?? mamoulMachineById(_machineId)?.name ?? '—';
      return MamoulCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.precision_manufacturing_outlined, size: 19, color: kMamoulColor),
            const SizedBox(width: 10),
            Expanded(child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold))),
            const Text('من التشغيلة', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
          ],
        ),
      );
    }
    if (_machinesLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: kMamoulColor))),
      );
    }
    if (_machinesError != null) return MamoulErrorView(message: _machinesError!, onRetry: _loadMachines);
    final options = mamoulMachines.value.where((m) => m.active || m.id == _machineId).toList();
    if (options.isEmpty) {
      return const InfoNote(
        text: 'لا توجد مكائن مضافة. أضف مكينة أولًا من زر «المكائن» في تبويب المعمول.',
        color: AppColors.warningText,
        icon: Icons.info_outline,
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
    final role = context.read<AuthService>().currentUser?.role;
    final canDelete = _editing && role != null && canManageMaintenance(role);

    return Scaffold(
      appBar: ScreenTopBar(
        title: _editing ? 'تعديل العطل' : 'تسجيل عطل',
        actions: [
          if (canDelete)
            IconButton(
              tooltip: 'حذف العطل',
              onPressed: _saving ? null : _delete,
              icon: const Icon(Icons.delete_outline),
              color: kMamoulDanger,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const MamoulFieldLabel('المكينة', required: true),
            _machineSection(),
            const SizedBox(height: 16),
            const MamoulFieldLabel('القطعة المعطّلة', required: true),
            MamoulChoiceRow<String>(
              options: _kComponents,
              labelOf: mamoulComponentLabel,
              selected: _component,
              onSelected: (v) => setState(() => _component = v),
            ),
            const SizedBox(height: 16),
            const MamoulFieldLabel('تحديد القطعة'),
            MamoulTextField(controller: _part, hint: 'مثال: بستون رقم ٢ / حساس الدفع', maxLength: 120),
            const SizedBox(height: 16),
            const MamoulFieldLabel('وصف العطل', required: true),
            MamoulTextField(controller: _description, hint: 'ماذا حصل بالضبط؟', maxLines: 3, maxLength: 1000),
            const SizedBox(height: 16),
            const MamoulFieldLabel('تاريخ العطل'),
            MamoulPickerField(
              text: '${mamoulWeekdayName(_date)} ${mamoulDateLabel(mamoulIsoDate(_date))}',
              hint: 'اختر التاريخ',
              icon: Icons.calendar_today_outlined,
              onTap: _pickDate,
            ),
            const SizedBox(height: 16),
            const MamoulFieldLabel('وقت العطل'),
            MamoulPickerField(
              text: _time == null ? '' : mamoulTimeLabel(mamoulTimeOf(_time!)),
              hint: 'اختر الوقت',
              icon: Icons.access_time,
              onTap: _pickTime,
              onClear: () => setState(() => _time = null),
            ),
            const SizedBox(height: 16),
            const MamoulFieldLabel('مدة توقف المكينة (دقائق)'),
            MamoulNumberField(controller: _downtime, hint: 'اختياري', decimal: false),
            const SizedBox(height: 16),
            const MamoulFieldLabel('الإجراء المتَّخذ'),
            MamoulTextField(controller: _action, hint: 'ماذا تم لإصلاحه؟', maxLines: 3, maxLength: 1000),
            if (_editing) ...[
              const SizedBox(height: 16),
              const MamoulFieldLabel('الحالة'),
              MamoulChoiceRow<String>(
                options: const ['open', 'resolved'],
                labelOf: (v) => v == 'open' ? 'مفتوح' : 'تم الحل',
                selected: _status,
                onSelected: (v) => setState(() => _status = v),
              ),
            ],
            const SizedBox(height: 22),
            PrimaryButton(
              label: _saving ? 'جارٍ الحفظ...' : (_editing ? 'حفظ التعديلات' : 'تسجيل العطل'),
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

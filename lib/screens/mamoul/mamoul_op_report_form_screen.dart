import 'package:flutter/material.dart';

import '../../models/mamoul_monitor.dart';
import '../../models/mamoul_op_report.dart';
import '../../services/api_client.dart';
import '../../services/mamoul_op_report_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'mamoul_widgets.dart';
import 'mamoul_workers_screen.dart';

/// أقصى عدد مجموعات مكائن وعاملات في التقرير (نفس حدود السيرفر).
const int kMamoulOpMaxGroups = 8;
const int kMamoulOpMaxWorkers = 12;

/// مجموعة مكائن أثناء التعبئة.
class _GroupDraft {
  final TextEditingController machines;
  final List<MamoulOpWorkerEntry> workers;

  _GroupDraft({String machines = '', List<MamoulOpWorkerEntry>? workers})
      : machines = TextEditingController(text: machines),
        workers = workers ?? <MamoulOpWorkerEntry>[];

  void dispose() => machines.dispose();
}

/// '302 - 305' → ['302', '305'].
List<String> _machineNames(String text) => text
    .split(RegExp(r'\s*[-–،,]\s*'))
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList();

/// 280500.0 → '280500'، 280500.5 → '280500.5' (للتعديل).
String _plainGrams(double g) {
  var s = g.toStringAsFixed(3);
  s = s.replaceFirst(RegExp(r'0+$'), '');
  s = s.replaceFirst(RegExp(r'\.$'), '');
  return s;
}

/// نموذج «تقرير تشغيل المعمول» بنفس ترتيب الورقة (Mamoul Operating Report):
/// بيانات الدفعة، ثم المكائن والعاملات، ثم الملاحظات والمشغّلة والتوقيع الجاهز.
/// يعيد معرّف التقرير بعد الحفظ.
class MamoulOpReportFormScreen extends StatefulWidget {
  final MamoulOpConfig config;
  final DateTime initialDate;
  final MamoulOpReport? existing;

  const MamoulOpReportFormScreen({super.key, required this.config, required this.initialDate, this.existing});

  @override
  State<MamoulOpReportFormScreen> createState() => _MamoulOpReportFormScreenState();
}

class _MamoulOpReportFormScreenState extends State<MamoulOpReportFormScreen> {
  late final TextEditingController _product;
  late final TextEditingController _batch;
  late final TextEditingController _weight;
  late final TextEditingController _notes;
  late final TextEditingController _operator;
  late DateTime _ballDate;
  TimeOfDay? _start;
  TimeOfDay? _end;
  final List<_GroupDraft> _groups = [];
  bool _useSignature = true;
  List<MamoulWorker> _workers = const [];
  bool _workersLoading = true;
  bool _saving = false;
  final String _clientToken = newMamoulClientToken();

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final d = widget.initialDate;
    _product = TextEditingController(text: e?.productName ?? widget.config.defaultProduct);
    _batch = TextEditingController(text: e?.batchNo ?? '');
    final g = e?.batchWeightG;
    _weight = TextEditingController(text: g == null ? '' : _plainGrams(g));
    _notes = TextEditingController(text: e?.notes ?? '');
    _operator = TextEditingController(text: e == null ? widget.config.defaultOperator : (e.operatorName ?? ''));
    _ballDate = (e == null ? null : mamoulParseDate(e.ballMakeDate)) ?? DateTime(d.year, d.month, d.day);
    _start = mamoulParseTime(e?.startTime);
    _end = mamoulParseTime(e?.endTime);
    _useSignature = e == null ? true : e.hasSignature;
    if (e != null && e.groups.isNotEmpty) {
      for (final grp in e.groups) {
        _addGroupDraft(_GroupDraft(machines: grp.machines, workers: List<MamoulOpWorkerEntry>.of(grp.workers)));
      }
    } else {
      // مجموعتان فارغتان كما في الورقة.
      _addGroupDraft(_GroupDraft());
      _addGroupDraft(_GroupDraft());
    }
    _operator.addListener(_refresh);
    _weight.addListener(_refresh);
    _loadWorkers();
    if (mamoulMachines.value.isEmpty) reloadMamoulMachines();
  }

  @override
  void dispose() {
    _product.dispose();
    _batch.dispose();
    _weight.dispose();
    _notes.dispose();
    _operator.dispose();
    for (final g in _groups) {
      g.dispose();
    }
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _addGroupDraft(_GroupDraft g) {
    g.machines.addListener(_refresh);
    _groups.add(g);
  }

  Future<void> _loadWorkers() async {
    try {
      final list = await MamoulOpReportService.fetchWorkers();
      if (!mounted) return;
      setState(() {
        _workers = list;
        _workersLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _workersLoading = false);
    }
  }

  // ------------------------------ الحقول ------------------------------

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _ballDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _ballDate = DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _pickTime({required bool start}) async {
    final initial = (start ? _start : _end) ?? TimeOfDay.now();
    final t = await showTimePicker(context: context, initialTime: initial);
    if (t == null) return;
    setState(() {
      if (start) {
        _start = t;
      } else {
        _end = t;
      }
    });
  }

  void _toggleMachine(_GroupDraft g, String name) {
    final list = _machineNames(g.machines.text);
    if (list.contains(name)) {
      list.remove(name);
    } else {
      list.add(name);
    }
    final order = mamoulMachines.value.map((m) => m.name).toList();
    final ordered = <String>[
      ...order.where(list.contains),
      ...list.where((n) => !order.contains(n)),
    ];
    g.machines.text = ordered.join(' - ');
  }

  void _addGroup() {
    if (_groups.length >= kMamoulOpMaxGroups) return;
    setState(() => _addGroupDraft(_GroupDraft()));
  }

  Future<void> _removeGroup(int index) async {
    final g = _groups[index];
    if (g.machines.text.trim().isNotEmpty || g.workers.isNotEmpty) {
      final ok = await confirmMamoul(
        context,
        title: 'حذف المجموعة',
        message: 'ستُحذف هذه المجموعة (المكائن والعاملات فيها) من هذا التقرير فقط.',
      );
      if (!ok || !mounted) return;
    }
    setState(() => _groups.removeAt(index));
    // يُتلف بعد إعادة البناء حتى لا يستعمله حقل النص وهو ما زال على الشاشة.
    WidgetsBinding.instance.addPostFrameCallback((_) => g.dispose());
  }

  Future<void> _pickWorker(_GroupDraft g) async {
    final chosen = _groups.expand((x) => x.workers).map((w) => w.workerId).whereType<String>().toSet();
    final picked = await showMamoulSheet<MamoulWorker>(
      context,
      (ctx) => _WorkerPickerSheet(
        workers: _workers,
        loading: _workersLoading,
        chosenIds: chosen,
        canAdd: widget.config.canWrite,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      g.workers.add(MamoulOpWorkerEntry.ofWorker(picked));
      if (!_workers.any((w) => w.id == picked.id)) {
        _workers = [..._workers, picked];
      }
    });
  }

  // ------------------------------ الحفظ ------------------------------

  Future<void> _save({bool allowDuplicate = false}) async {
    FocusScope.of(context).unfocus();
    final batch = _batch.text.trim();
    if (batch.isEmpty) {
      showMamoulSnack(context, 'اكتبي رقم الدفعة (Batch no)', error: true);
      return;
    }
    final weight = mamoulParseGrams(_weight.text);
    if (weight != null && (weight.isNaN || weight <= 0)) {
      showMamoulSnack(context, 'وزن الدفعة غير صحيح — اكتبيه بالجرام، مثل 280500', error: true);
      return;
    }
    final groups = <MamoulOpGroup>[];
    for (final g in _groups) {
      final machines = g.machines.text.trim();
      if (machines.isEmpty && g.workers.isEmpty) continue;
      groups.add(MamoulOpGroup(machines: machines, workers: List<MamoulOpWorkerEntry>.of(g.workers)));
    }
    final product = _product.text.trim();
    final notes = _notes.text.trim();
    final operatorName = _operator.text.trim();
    final draft = MamoulOpReportDraft(
      productName: product.isEmpty ? widget.config.defaultProduct : product,
      batchNo: batch,
      ballMakeDate: mamoulIsoDate(_ballDate),
      batchWeightG: weight,
      startTime: _start == null ? null : mamoulTimeOf(_start!),
      endTime: _end == null ? null : mamoulTimeOf(_end!),
      notes: notes.isEmpty ? null : notes,
      operatorName: operatorName.isEmpty ? null : operatorName,
      useSignature: _useSignature,
      groups: groups,
    );

    setState(() => _saving = true);
    try {
      final existing = widget.existing;
      final MamoulOpReport saved;
      if (existing == null) {
        saved = await MamoulOpReportService.createReport(draft, clientToken: _clientToken, allowDuplicate: allowDuplicate);
      } else {
        saved = await MamoulOpReportService.updateReport(existing.id, draft, allowDuplicate: allowDuplicate);
      }
      notifyMamoulOpChanged();
      if (!mounted) return;
      showMamoulSnack(context, existing == null ? 'حُفظ تقرير الدفعة ${saved.batchNo}' : 'حُفظت التعديلات');
      Navigator.of(context).pop(saved.id);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      if (e.statusCode == 409 && !allowDuplicate) {
        final ok = await confirmMamoul(
          context,
          title: 'رقم دفعة مكرر',
          message: 'رقم الدفعة «$batch» مسجَّل في تقرير آخر. هل تريدين الحفظ رغم ذلك؟',
          confirmLabel: 'حفظ رغم ذلك',
          danger: false,
        );
        if (ok && mounted) await _save(allowDuplicate: true);
        return;
      }
      showMamoulSnack(context, e.message, error: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMamoulSnack(context, mamoulErrorText(e), error: true);
    }
  }

  // ------------------------------ الواجهة ------------------------------

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 10),
        child: Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: kMamoulColor)),
      );

  Widget _weightHelper() {
    final g = mamoulParseGrams(_weight.text);
    if (g == null) {
      return const Text('الوزن بالجرام (مثل الورقة: 280,500)', style: TextStyle(fontSize: 12, color: AppColors.textMuted));
    }
    if (g.isNaN || g <= 0) {
      return const Text('اكتبي الوزن بالأرقام فقط', style: TextStyle(fontSize: 12, color: kMamoulDanger));
    }
    return Text(
      '= ${mamoulGramsText(g)} (${mamoulKgText(g)})',
      style: const TextStyle(fontSize: 12.5, color: AppColors.successText, fontWeight: FontWeight.w600),
    );
  }

  Widget _groupCard(int index, _GroupDraft g) {
    return Padding(
      key: ObjectKey(g),
      padding: const EdgeInsets.only(bottom: 12),
      child: MamoulCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'المجموعة ${mamoulCount(index + 1)}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                ),
                if (_groups.length > 1)
                  IconButton(
                    tooltip: 'حذف المجموعة',
                    onPressed: _saving ? null : () => _removeGroup(index),
                    icon: const Icon(Icons.delete_outline, color: kMamoulDanger, size: 20),
                  ),
              ],
            ),
            const MamoulFieldLabel('أرقام المكائن (Machine no)'),
            MamoulTextField(controller: g.machines, hint: 'مثل: 302 - 305', maxLength: 60),
            ValueListenableBuilder<List<MamoulMachine>>(
              valueListenable: mamoulMachines,
              builder: (context, machines, _) {
                final active = machines.where((m) => m.active).toList();
                if (active.isEmpty) return const SizedBox.shrink();
                final selected = _machineNames(g.machines.text);
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final m in active)
                        FilterChip(
                          label: Text(m.name, style: const TextStyle(fontSize: 12.5)),
                          selected: selected.contains(m.name),
                          onSelected: _saving ? null : (_) => _toggleMachine(g, m.name),
                          selectedColor: kMamoulColor.withOpacity(0.14),
                          checkmarkColor: kMamoulColor,
                          backgroundColor: AppColors.surface,
                          side: BorderSide(color: selected.contains(m.name) ? kMamoulColor : AppColors.border),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            MamoulFieldLabel('العاملات (${mamoulCount(g.workers.length)})'),
            if (g.workers.isEmpty)
              const Text('لم تُضف عاملات بعد', style: TextStyle(fontSize: 12.5, color: AppColors.textFaint))
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < g.workers.length; i++)
                    InputChip(
                      label: Text(g.workers[i].label, style: const TextStyle(fontSize: 13)),
                      onDeleted: _saving ? null : () => setState(() => g.workers.removeAt(i)),
                      deleteIconColor: AppColors.textMuted,
                      backgroundColor: AppColors.surface,
                      side: const BorderSide(color: AppColors.border),
                    ),
                ],
              ),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: _saving || g.workers.length >= kMamoulOpMaxWorkers ? null : () => _pickWorker(g),
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                label: const Text('إضافة عاملة', style: TextStyle(fontWeight: FontWeight.bold)),
                style: TextButton.styleFrom(foregroundColor: kMamoulColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _signatureSection() {
    final name = _operator.text;
    final png = widget.config.signaturePngFor(name);
    final existing = widget.existing;
    final has = png != null ||
        widget.config.hasSignatureFor(name) ||
        (existing != null && existing.hasSignature && mamoulSameName(existing.operatorName, name));
    if (!has) {
      return const InfoNote(
        text: 'لا يوجد توقيع محفوظ لهذا الاسم. يحفظه مسؤول الإنتاج مرة واحدة من زر «التوقيع» في قائمة التقارير.',
        color: AppColors.warningText,
        icon: Icons.info_outline,
      );
    }
    return MamoulCard(
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('إرفاق التوقيع الجاهز (Signature)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              ),
              Switch(value: _useSignature, onChanged: _saving ? null : (v) => setState(() => _useSignature = v)),
            ],
          ),
          if (_useSignature)
            png != null
                ? Container(
                    height: 72,
                    alignment: AlignmentDirectional.centerStart,
                    child: Image.memory(png, height: 62, fit: BoxFit.contain),
                  )
                : const Text('سيُرفق توقيعها المحفوظ تلقائيًا', style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final startText = _start == null ? '' : mamoulTimeLabel(mamoulTimeOf(_start!));
    final endText = _end == null ? '' : mamoulTimeLabel(mamoulTimeOf(_end!));

    return Scaffold(
      appBar: ScreenTopBar(title: _isEdit ? 'تعديل تقرير التشغيل' : 'تقرير تشغيل جديد'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          const InfoNote(
            text: 'نفس ترتيب ورقة Mamoul Operating Report. بعد الحفظ يمكن طباعة التقرير بنفس شكل الورقة.',
            color: kMamoulColor,
            icon: Icons.description_outlined,
          ),
          const SizedBox(height: 10),
          _section('بيانات الدفعة'),
          const MamoulFieldLabel('اسم المنتج (Production name)'),
          MamoulTextField(controller: _product, hint: 'معمول كويتي', maxLength: 80),
          const SizedBox(height: 12),
          const MamoulFieldLabel('رقم الدفعة (Batch no)', required: true),
          TextField(
            controller: _batch,
            maxLength: 40,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            textCapitalization: TextCapitalization.characters,
            decoration: fieldDecoration(hint: 'مثل: FM01926318').copyWith(counterText: ''),
          ),
          const SizedBox(height: 12),
          const MamoulFieldLabel('تاريخ تكوير الكرات (Ball make date)', required: true),
          MamoulPickerField(
            text: mamoulDateLabel(mamoulIsoDate(_ballDate)),
            hint: 'اختاري التاريخ',
            icon: Icons.calendar_today_outlined,
            onTap: _pickDate,
          ),
          const SizedBox(height: 12),
          const MamoulFieldLabel('وزن الدفعة بالجرام (Batch weight)'),
          MamoulNumberField(controller: _weight, hint: 'مثل: 280500'),
          const SizedBox(height: 6),
          _weightHelper(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const MamoulFieldLabel('وقت البداية (Time)'),
                    MamoulPickerField(
                      text: startText,
                      hint: 'مثل ٠٥:٢٥',
                      icon: Icons.schedule,
                      onTap: () => _pickTime(start: true),
                      onClear: () => setState(() => _start = null),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const MamoulFieldLabel('وقت النهاية (Time)'),
                    MamoulPickerField(
                      text: endText,
                      hint: 'مثل ٠٦:٤٠',
                      icon: Icons.schedule,
                      onTap: () => _pickTime(start: false),
                      onClear: () => setState(() => _end = null),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _section('أسماء العاملات (Workers names)'),
          for (var i = 0; i < _groups.length; i++) _groupCard(i, _groups[i]),
          if (_groups.length < kMamoulOpMaxGroups)
            MamoulOutlineButton(
              label: 'إضافة مجموعة مكائن أخرى',
              icon: Icons.add,
              onPressed: _saving ? null : _addGroup,
            ),
          const SizedBox(height: 18),
          _section('الملاحظات والتوقيع'),
          const MamoulFieldLabel('ملاحظات (NOTE)'),
          MamoulTextField(controller: _notes, hint: 'اختياري', maxLines: 3, maxLength: 1000),
          const SizedBox(height: 12),
          const MamoulFieldLabel('المشغّلة (Operate by)'),
          MamoulTextField(controller: _operator, hint: 'اسم المشغّلة', maxLength: 80),
          const SizedBox(height: 10),
          _signatureSection(),
          const SizedBox(height: 22),
          PrimaryButton(
            label: _saving ? 'جارٍ الحفظ…' : 'حفظ التقرير',
            color: kMamoulColor,
            icon: Icons.save_outlined,
            onPressed: _saving ? null : () => _save(),
          ),
        ],
      ),
    );
  }
}

/// نافذة اختيار عاملة من القائمة (مع بحث، وإضافة عاملة جديدة غير موجودة).
class _WorkerPickerSheet extends StatefulWidget {
  final List<MamoulWorker> workers;
  final bool loading;
  final Set<String> chosenIds;
  final bool canAdd;

  const _WorkerPickerSheet({
    required this.workers,
    required this.loading,
    required this.chosenIds,
    required this.canAdd,
  });

  @override
  State<_WorkerPickerSheet> createState() => _WorkerPickerSheetState();
}

class _WorkerPickerSheetState extends State<_WorkerPickerSheet> {
  String _query = '';

  Future<void> _addNew() async {
    final w = await showMamoulWorkerDialog(context, initialName: _query.isEmpty ? null : _query);
    if (w == null || !mounted) return;
    Navigator.of(context).pop(w);
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.toLowerCase();
    final list = widget.workers
        .where((w) => w.active)
        .where((w) => q.isEmpty || w.name.toLowerCase().contains(q) || (w.employeeNumber ?? '').toLowerCase().contains(q))
        .toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('اختاري العاملة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        TextField(
          autofocus: false,
          onChanged: (v) => setState(() => _query = v.trim()),
          decoration: fieldDecoration(hint: 'بحث بالاسم').copyWith(prefixIcon: const Icon(Icons.search, size: 20)),
        ),
        const SizedBox(height: 10),
        if (widget.canAdd)
          MamoulOutlineButton(
            label: _query.isEmpty ? 'إضافة عاملة جديدة إلى القائمة' : 'إضافة «$_query» كعاملة جديدة',
            icon: Icons.person_add_alt_1_outlined,
            onPressed: _addNew,
          ),
        const SizedBox(height: 8),
        if (widget.loading && widget.workers.isEmpty)
          const MamoulLoadingView()
        else if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Text(
              widget.workers.isEmpty ? 'لا توجد عاملات في القائمة بعد — أضيفي أول عاملة.' : 'لا توجد نتيجة بهذا الاسم.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          )
        else
          for (final w in list)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              enabled: !widget.chosenIds.contains(w.id),
              leading: Icon(
                widget.chosenIds.contains(w.id) ? Icons.check_circle : Icons.person_outline,
                color: widget.chosenIds.contains(w.id) ? AppColors.successText : kMamoulColor,
              ),
              title: Text(w.label, style: const TextStyle(fontSize: 14.5)),
              subtitle: widget.chosenIds.contains(w.id)
                  ? const Text('مضافة في هذا التقرير', style: TextStyle(fontSize: 11.5))
                  : null,
              onTap: () => Navigator.of(context).pop(w),
            ),
      ],
    );
  }
}

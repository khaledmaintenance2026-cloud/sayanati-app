import 'package:flutter/material.dart';

import '../../models/mamoul_monitor.dart' show mamoulCount;
import '../../models/mamoul_op_report.dart';
import '../../services/mamoul_op_report_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'mamoul_widgets.dart';

/// حوار إضافة عاملة جديدة أو تعديل بياناتها. يعيد العاملة بعد الحفظ، أو null لو أُلغي.
Future<MamoulWorker?> showMamoulWorkerDialog(BuildContext context, {MamoulWorker? existing, String? initialName}) {
  return showDialog<MamoulWorker>(
    context: context,
    builder: (_) => _WorkerDialog(existing: existing, initialName: initialName),
  );
}

class _WorkerDialog extends StatefulWidget {
  final MamoulWorker? existing;
  final String? initialName;

  const _WorkerDialog({this.existing, this.initialName});

  @override
  State<_WorkerDialog> createState() => _WorkerDialogState();
}

class _WorkerDialogState extends State<_WorkerDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? widget.initialName ?? '');
  late final TextEditingController _number = TextEditingController(text: widget.existing?.employeeNumber ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'اكتبي اسم العاملة');
      return;
    }
    final number = _number.text.trim();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final existing = widget.existing;
      final MamoulWorker saved;
      if (existing == null) {
        saved = await MamoulOpReportService.addWorker(name: name, employeeNumber: number.isEmpty ? null : number);
      } else {
        saved = await MamoulOpReportService.updateWorker(
          existing.id,
          name: name,
          employeeNumber: number.isEmpty ? null : number,
        );
      }
      notifyMamoulOpChanged();
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = mamoulErrorText(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'إضافة عاملة' : 'تعديل بيانات العاملة'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const MamoulFieldLabel('اسم العاملة', required: true),
            MamoulTextField(controller: _name, hint: 'مثل: فاطمة أبكر', maxLength: 80),
            const SizedBox(height: 12),
            const MamoulFieldLabel('الرقم الوظيفي (اختياري)'),
            MamoulTextField(controller: _number, hint: 'يميّز بين الأسماء المتشابهة', maxLength: 30),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(fontSize: 12.5, color: kMamoulDanger)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: kMamoulColor))
              : const Text('حفظ', style: TextStyle(color: kMamoulColor, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}

/// قائمة عاملات منطقة المعمول: إضافة وتعديل وإخفاء (لا حذف — اسم العاملة يبقى
/// في التقارير القديمة). الإضافة والتعديل للإنتاج ومسؤول الإنتاج ومدير النظام،
/// وغيرهم يتصفّح القائمة فقط (القيد الملزم على السيرفر).
class MamoulWorkersScreen extends StatefulWidget {
  final bool canWrite;

  const MamoulWorkersScreen({super.key, required this.canWrite});

  @override
  State<MamoulWorkersScreen> createState() => _MamoulWorkersScreenState();
}

class _MamoulWorkersScreenState extends State<MamoulWorkersScreen> {
  List<MamoulWorker>? _workers;
  bool _loading = true;
  String? _error;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await MamoulOpReportService.fetchWorkers(all: true);
      if (!mounted) return;
      setState(() {
        _workers = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = mamoulErrorText(e);
        _loading = false;
      });
    }
  }

  Future<void> _add() async {
    final w = await showMamoulWorkerDialog(context);
    if (w == null || !mounted) return;
    showMamoulSnack(context, 'أُضيفت ${w.name} إلى القائمة');
    _load();
  }

  Future<void> _edit(MamoulWorker worker) async {
    final w = await showMamoulWorkerDialog(context, existing: worker);
    if (w == null || !mounted) return;
    showMamoulSnack(context, 'حُفظت بيانات ${w.name}');
    _load();
  }

  Future<void> _toggle(MamoulWorker worker) async {
    if (worker.active) {
      final ok = await confirmMamoul(
        context,
        title: 'إخفاء العاملة',
        message: 'ستختفي «${worker.name}» من قائمة الاختيار في التقارير الجديدة، ويبقى اسمها في التقارير القديمة. '
            'يمكنك إظهارها مرة أخرى في أي وقت.',
        confirmLabel: 'إخفاء',
      );
      if (!ok) return;
    }
    try {
      await MamoulOpReportService.setWorkerActive(worker.id, !worker.active);
      notifyMamoulOpChanged();
      if (!mounted) return;
      showMamoulSnack(context, worker.active ? 'أُخفيت ${worker.name}' : 'عادت ${worker.name} إلى القائمة');
      _load();
    } catch (e) {
      if (!mounted) return;
      showMamoulSnack(context, mamoulErrorText(e), error: true);
    }
  }

  Widget _tile(MamoulWorker w) {
    final sub = <String>[
      if (w.employeeNumber != null) 'الرقم الوظيفي ${w.employeeNumber}',
      if (w.usedCount > 0) 'في ${mamoulCount(w.usedCount)} تقرير',
      if (!w.active) 'مخفية',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: MamoulCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        onTap: widget.canWrite ? () => _edit(w) : null,
        child: Row(
          children: [
            CircleAvatar(
              radius: 17,
              backgroundColor: (w.active ? kMamoulColor : AppColors.textFaint).withOpacity(0.14),
              child: Icon(Icons.person_outline, size: 19, color: w.active ? kMamoulColor : AppColors.textMuted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    w.name,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.bold,
                      color: w.active ? AppColors.textPrimary : AppColors.textMuted,
                    ),
                  ),
                  if (sub.isNotEmpty)
                    Text(sub.join(' · '), style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            if (widget.canWrite)
              PopupMenuButton<String>(
                tooltip: 'خيارات',
                onSelected: (v) {
                  if (v == 'edit') _edit(w);
                  if (v == 'toggle') _toggle(w);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem<String>(value: 'edit', child: Text('تعديل')),
                  PopupMenuItem<String>(value: 'toggle', child: Text(w.active ? 'إخفاء من القائمة' : 'إظهار في القائمة')),
                ],
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    final workers = _workers;
    if (_loading && workers == null) {
      children.add(const MamoulLoadingView());
    } else if (_error != null && workers == null) {
      children.add(MamoulErrorView(message: _error!, onRetry: _load));
    } else if (workers != null) {
      if (workers.isEmpty) {
        children.add(MamoulEmptyState(
          icon: Icons.groups_outlined,
          text: widget.canWrite
              ? 'لا توجد عاملات في القائمة بعد.\nاضغطي «إضافة عاملة» لإضافة أول اسم.'
              : 'لا توجد عاملات في القائمة بعد.',
        ));
      } else {
        children.add(TextField(
          onChanged: (v) => setState(() => _filter = v.trim()),
          decoration: fieldDecoration(hint: 'بحث بالاسم أو الرقم الوظيفي').copyWith(
            prefixIcon: const Icon(Icons.search, size: 20),
          ),
        ));
        children.add(const SizedBox(height: 12));
        final active = workers.where((w) => w.active).length;
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            'في القائمة ${mamoulCount(active)} عاملة',
            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
          ),
        ));
        final f = _filter.toLowerCase();
        final shown = f.isEmpty
            ? workers
            : workers
                .where((w) => w.name.toLowerCase().contains(f) || (w.employeeNumber ?? '').toLowerCase().contains(f))
                .toList();
        for (final w in shown) {
          children.add(_tile(w));
        }
      }
    }

    return Scaffold(
      appBar: const ScreenTopBar(title: 'عاملات المعمول'),
      floatingActionButton: widget.canWrite
          ? FloatingActionButton.extended(
              heroTag: 'mamoul_add_worker',
              backgroundColor: kMamoulColor,
              foregroundColor: Colors.white,
              onPressed: _add,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: const Text('إضافة عاملة', style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 96),
          children: children,
        ),
      ),
    );
  }
}

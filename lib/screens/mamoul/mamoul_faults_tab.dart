import 'package:flutter/material.dart';

import '../../models/mamoul_monitor.dart';
import '../../services/mamoul_monitor_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'mamoul_fault_form_screen.dart';
import 'mamoul_widgets.dart';

/// تبويب "الأعطال": سجل أعطال البستونات والحساسات والمحركات في منطقة المعمول،
/// مع تصفية بالحالة والمكينة والفترة، وإجماليات (عدد، مفتوح، ساعات توقف،
/// توزيع حسب القطعة). مرِّر [fixedMachineId] ليعرض أعطال مكينة واحدة فقط.
class MamoulFaultsTab extends StatefulWidget {
  final String? fixedMachineId;

  const MamoulFaultsTab({super.key, this.fixedMachineId});

  @override
  State<MamoulFaultsTab> createState() => _MamoulFaultsTabState();
}

class _MamoulFaultsTabState extends State<MamoulFaultsTab> with AutomaticKeepAliveClientMixin {
  /// null = الكل، 'open' = مفتوحة، 'resolved' = تم حلّها.
  String? _status;
  String? _machineFilter;
  int _days = 90;
  MamoulFaultsResult? _result;
  bool _loading = true;
  String? _error;
  int _requestId = 0;

  @override
  bool get wantKeepAlive => true;

  String? get _effectiveMachineId => widget.fixedMachineId ?? _machineFilter;

  @override
  void initState() {
    super.initState();
    mamoulChanged.addListener(_onDataChanged);
    _load();
  }

  @override
  void dispose() {
    mamoulChanged.removeListener(_onDataChanged);
    super.dispose();
  }

  void _onDataChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final id = ++_requestId;
    if (mounted) setState(() => _error = null);
    try {
      final r = await MamoulMonitorService.fetchFaults(
        status: _status,
        machineId: _effectiveMachineId,
        from: mamoulFromDays(_days),
        to: mamoulToday(),
      );
      if (!mounted || id != _requestId) return;
      setState(() {
        _result = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = mamoulErrorText(e);
        _loading = false;
      });
    }
  }

  void _reloadFor(VoidCallback change) {
    setState(() {
      change();
      _loading = true;
    });
    _load();
  }

  Future<void> _newFault() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => MamoulFaultFormScreen(initialMachineId: _effectiveMachineId)),
    );
  }

  Future<void> _openFault(MamoulFault f) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => MamoulFaultFormScreen(existing: f)),
    );
  }

  Future<void> _resolve(MamoulFault f) async {
    final done = await showMamoulSheet<bool>(context, (ctx) => _ResolveFaultSheet(fault: f));
    if (done == true && mounted) showMamoulSnack(context, 'سُجّل العطل كمحلول');
  }

  // ------------------------------- بناء الواجهة -------------------------------

  Widget _summary(MamoulFaultsResult r) {
    final byComponent = r.byComponent.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            KpiCard(value: mamoulCount(r.faults.length), label: 'عدد الأعطال', valueColor: kMamoulColor),
            const SizedBox(width: 10),
            KpiCard(
              value: mamoulCount(r.openCount),
              label: 'مفتوحة',
              valueColor: r.openCount > 0 ? kMamoulDanger : AppColors.successText,
            ),
            const SizedBox(width: 10),
            KpiCard(value: mamoulDuration(r.downtimeMinutes), label: 'مدة التوقف', valueColor: AppColors.maintenance),
          ],
        ),
        if (byComponent.isNotEmpty) ...[
          const SizedBox(height: 10),
          MamoulCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('توزيع الأعطال حسب القطعة', style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final e in byComponent)
                      StatusPill(
                        label: '${mamoulComponentLabel(e.key)} ${mamoulCount(e.value)}',
                        color: kMamoulColor,
                        background: kMamoulColor.withOpacity(0.10),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _faultCard(MamoulFault f) {
    final when = <String>[
      mamoulDateLabel(f.date),
      if (f.time != null) mamoulTimeLabel(f.time!),
    ].join(' — ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MamoulCard(
        onTap: () => _openFault(f),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(mamoulComponentIcon(f.component), size: 20, color: f.isOpen ? kMamoulDanger : AppColors.textMuted),
                const SizedBox(width: 8),
                Expanded(child: Text(f.title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold))),
                StatusPill(
                  label: f.isOpen ? 'مفتوح' : 'تم الحل',
                  color: f.isOpen ? kMamoulDanger : AppColors.successText,
                  background: f.isOpen ? kMamoulDanger.withOpacity(0.10) : AppColors.successBg,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              [if (f.machineName != null) f.machineName!, when].join(' — '),
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 8),
            Text(f.description, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
            if (f.downtimeMinutes != null && f.downtimeMinutes! > 0) ...[
              const SizedBox(height: 6),
              Text('توقف المكينة: ${mamoulDuration(f.downtimeMinutes)}', style: const TextStyle(fontSize: 12, color: AppColors.warningText)),
            ],
            if (f.actionTaken != null) ...[
              const SizedBox(height: 6),
              Text('الإجراء: ${f.actionTaken}', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.5)),
            ],
            if (f.isOpen) ...[
              const SizedBox(height: 4),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => _resolve(f),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text('تم الإصلاح'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.successText),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final children = <Widget>[
      MamoulChoiceRow<String?>(
        options: const <String?>[null, 'open', 'resolved'],
        labelOf: (v) => v == null ? 'الكل' : (v == 'open' ? 'مفتوحة' : 'تم حلّها'),
        selected: _status,
        onSelected: (v) => _reloadFor(() => _status = v),
      ),
      const SizedBox(height: 10),
      MamoulDaysChips(days: _days, onChanged: (d) => _reloadFor(() => _days = d)),
      const SizedBox(height: 12),
    ];

    if (widget.fixedMachineId == null) {
      children.add(
        ValueListenableBuilder<List<MamoulMachine>>(
          valueListenable: mamoulMachines,
          builder: (context, machines, _) {
            if (machines.length < 2) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: MamoulMachineChips(
                machines: machines,
                selectedId: _machineFilter,
                onChanged: (id) => _reloadFor(() => _machineFilter = id),
              ),
            );
          },
        ),
      );
    }

    final result = _result;
    if (_loading && result == null) {
      children.add(const MamoulLoadingView());
    } else if (_error != null && result == null) {
      children.add(MamoulErrorView(message: _error!, onRetry: _load));
    } else if (result != null) {
      if (result.faults.isEmpty) {
        children.add(const MamoulEmptyState(
          icon: Icons.build_circle_outlined,
          text: 'لا توجد أعطال مسجّلة بهذه التصفية.\nسجّل أي عطل يحدث في بستون أو حساس أو محرك بزر «تسجيل عطل».',
        ));
      } else {
        children.add(_summary(result));
        children.add(const SizedBox(height: 14));
        for (final f in result.faults) {
          children.add(_faultCard(f));
        }
      }
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 96),
            children: children,
          ),
        ),
        Positioned(
          bottom: 20,
          left: 20,
          child: FloatingActionButton.extended(
            heroTag: widget.fixedMachineId == null ? 'mamoul_new_fault' : 'mamoul_new_fault_${widget.fixedMachineId}',
            backgroundColor: kMamoulColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            onPressed: _newFault,
            icon: const Icon(Icons.add),
            label: const Text('تسجيل عطل', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

/// نافذة "تم الإصلاح": يكتب الفني ما تم عمله (اختياري) ثم يُسجَّل العطل كمحلول.
class _ResolveFaultSheet extends StatefulWidget {
  final MamoulFault fault;

  const _ResolveFaultSheet({required this.fault});

  @override
  State<_ResolveFaultSheet> createState() => _ResolveFaultSheetState();
}

class _ResolveFaultSheetState extends State<_ResolveFaultSheet> {
  late final TextEditingController _action;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _action = TextEditingController(text: widget.fault.actionTaken ?? '');
  }

  @override
  void dispose() {
    _action.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final text = _action.text.trim();
      await MamoulMonitorService.setFaultStatus(
        widget.fault.id,
        'resolved',
        actionTaken: text.isEmpty ? null : text,
      );
      notifyMamoulChanged();
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Center(
          child: Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(4)),
          ),
        ),
        const SizedBox(height: 14),
        const Text('تم إصلاح العطل', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(widget.fault.title, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
        const SizedBox(height: 14),
        const MamoulFieldLabel('ماذا تم لإصلاحه؟ (اختياري)'),
        MamoulTextField(controller: _action, hint: 'مثال: تغيير البستون وضبط الحساس', maxLines: 3, maxLength: 1000),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(fontSize: 13, color: kMamoulDanger, height: 1.5)),
        ],
        const SizedBox(height: 14),
        PrimaryButton(
          label: _saving ? 'جارٍ الحفظ...' : 'تسجيل كمحلول',
          color: kMamoulColor,
          icon: Icons.check,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}

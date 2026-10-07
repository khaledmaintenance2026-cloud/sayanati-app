import 'package:flutter/material.dart';

import '../../models/mamoul_monitor.dart';
import '../../services/mamoul_monitor_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'mamoul_run_form_screen.dart';
import 'mamoul_run_screen.dart';
import 'mamoul_widgets.dart';

/// تبويب "التشغيلات": يتنقّل المستخدم بين الأيام ويرى تشغيلات المعمول وحالة
/// أوزانها، ويبدأ تشغيلة جديدة. لو مُرِّر [fixedMachineId] (غرفة مكينة) فكل
/// ما يظهر ويُنشأ يخصّ هذه المكينة فقط؛ وإلا يظهر شريط لتصفية المكائن.
class MamoulRunsTab extends StatefulWidget {
  final String? fixedMachineId;

  const MamoulRunsTab({super.key, this.fixedMachineId});

  @override
  State<MamoulRunsTab> createState() => _MamoulRunsTabState();
}

class _MamoulRunsTabState extends State<MamoulRunsTab> with AutomaticKeepAliveClientMixin {
  late DateTime _day;
  String? _machineFilter;
  MamoulRunsResult? _result;
  bool _loading = true;
  String? _error;
  int _requestId = 0;

  @override
  bool get wantKeepAlive => true;

  String? get _effectiveMachineId => widget.fixedMachineId ?? _machineFilter;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _day = DateTime(now.year, now.month, now.day);
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
      final r = await MamoulMonitorService.fetchRunsOfDay(mamoulIsoDate(_day), machineId: _effectiveMachineId);
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

  void _setDay(DateTime d) {
    setState(() {
      _day = DateTime(d.year, d.month, d.day);
      _result = null;
      _loading = true;
    });
    _load();
  }

  void _shift(int days) => _setDay(DateTime(_day.year, _day.month, _day.day + days));

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _day,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) _setDay(picked);
  }

  bool get _isToday {
    final now = DateTime.now();
    return _day.year == now.year && _day.month == now.month && _day.day == now.day;
  }

  Future<void> _newRun() async {
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => MamoulRunFormScreen(initialDate: _day, initialMachineId: _effectiveMachineId),
      ),
    );
    if (id != null && mounted) _openRun(id);
  }

  Future<void> _openRun(String id) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => MamoulRunScreen(runId: id)),
    );
  }

  // ------------------------------- بناء الواجهة -------------------------------

  Widget _totals(MamoulTotals t) {
    final d = t.defects;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            KpiCard(value: mamoulCount(t.runsCount), label: 'التشغيلات', valueColor: kMamoulColor),
            const SizedBox(width: 10),
            KpiCard(value: mamoulCount(t.piecesCount), label: 'القطع المقاسة', valueColor: AppColors.maintenance),
            const SizedBox(width: 10),
            KpiCard(
              value: t.piecesCount == 0 ? '—' : mamoulPct(t.outPct),
              label: 'خارج النطاق',
              valueColor: t.outCount > 0 ? kMamoulDanger : AppColors.successText,
            ),
          ],
        ),
        const SizedBox(height: 10),
        MamoulCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Expanded(child: MamoulStat(label: 'متوسط الوزن', value: mamoulWeight(t.avgWeight))),
              Expanded(child: MamoulStat(label: 'توائم', value: mamoulCount(d.twins))),
              Expanded(child: MamoulStat(label: 'زوائد', value: mamoulCount(d.flash))),
              Expanded(child: MamoulStat(label: 'مرفوض', value: mamoulCount(d.rejected))),
              Expanded(
                child: MamoulStat(
                  label: 'أعطال مفتوحة',
                  value: mamoulCount(t.faultsOpen),
                  color: t.faultsOpen > 0 ? kMamoulDanger : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _runCard(MamoulRun run) {
    final s = run.summary;
    final parts = <String>[
      if (run.shift != null) run.shift!,
      'هدف ${mamoulNum(run.targetWeight)}',
      if (run.startTime != null) 'من ${mamoulTimeLabel(run.startTime!)}',
      if (run.endTime != null) 'إلى ${mamoulTimeLabel(run.endTime!)}',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MamoulCard(
        onTap: () => _openRun(run.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.precision_manufacturing_outlined, size: 19, color: kMamoulColor),
                const SizedBox(width: 8),
                Expanded(child: Text(run.machineLabel, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                StatusPill(
                  label: run.isOpen ? 'جارية' : 'مغلقة',
                  color: run.isOpen ? AppColors.successText : AppColors.textSecondary,
                  background: run.isOpen ? AppColors.successBg : AppColors.divider,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(parts.join(' — '), style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
            const SizedBox(height: 10),
            if (s.samplesCount == 0)
              const Text('لا عيّنات بعد', style: TextStyle(fontSize: 13, color: AppColors.textFaint))
            else
              Row(
                children: [
                  Expanded(child: MamoulStat(label: 'القطع', value: mamoulCount(s.piecesCount))),
                  Expanded(
                    child: MamoulStat(label: 'المتوسط', value: mamoulWeight(s.stats.avg), color: mamoulLevelColor(s.stats.level)),
                  ),
                  Expanded(
                    child: MamoulStat(
                      label: 'خارج النطاق',
                      value: s.stats.outCount == 0 ? '٠' : mamoulPct(s.stats.outPct),
                      color: s.stats.outCount == 0 ? AppColors.successText : kMamoulDanger,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (s.lastSampleLevel != null)
                  MamoulLevelPill(
                    level: s.lastSampleLevel!,
                    label: 'آخر عيّنة: ${mamoulLevelLabel(s.lastSampleLevel!)}',
                  ),
                if (s.defects.total > 0)
                  StatusPill(
                    label: 'عيوب ${mamoulCount(s.defects.total)}',
                    color: kMamoulDanger,
                    background: kMamoulDanger.withOpacity(0.10),
                  ),
                if (s.faultsOpen > 0)
                  StatusPill(
                    label: 'أعطال مفتوحة ${mamoulCount(s.faultsOpen)}',
                    color: AppColors.warningText,
                    background: AppColors.warningBg,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final subtitle = '${mamoulWeekdayName(_day)}${_isToday ? ' — اليوم' : ''}';

    final children = <Widget>[
      MamoulPeriodBar(
        title: mamoulDateLabel(mamoulIsoDate(_day)),
        subtitle: subtitle,
        onPrevious: () => _shift(-1),
        onNext: () => _shift(1),
        onTap: _pickDate,
      ),
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
                onChanged: (id) {
                  setState(() {
                    _machineFilter = id;
                    _loading = true;
                  });
                  _load();
                },
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
      if (result.runs.isEmpty) {
        children.add(const MamoulEmptyState(
          icon: Icons.precision_manufacturing_outlined,
          text: 'لا توجد تشغيلات مسجّلة في هذا اليوم.\nاضغط «تشغيلة جديدة» لبدء تسجيل تشغيلة.',
        ));
      } else {
        children.add(_totals(result.totals));
        children.add(const SizedBox(height: 14));
        for (final r in result.runs) {
          children.add(_runCard(r));
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
            heroTag: widget.fixedMachineId == null ? 'mamoul_new_run' : 'mamoul_new_run_${widget.fixedMachineId}',
            backgroundColor: kMamoulColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            onPressed: _newRun,
            icon: const Icon(Icons.add),
            label: const Text('تشغيلة جديدة', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

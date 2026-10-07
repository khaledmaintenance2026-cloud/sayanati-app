import 'package:flutter/material.dart';

import '../../models/mamoul_monitor.dart';
import '../../services/mamoul_monitor_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'mamoul_widgets.dart';

/// تبويب "التحليل": يجيب على سؤال "لو ضبطت السرعات على كذا، كم ستكون الأوزان؟".
/// يجمع كل عيّنات الأوزان بحسب (المكينة + سرعات السير والدفع والدوار + هدف
/// الوزن) ويقترح أفضل ضبط لكل مكينة (أقل قطع خارج النطاق ثم الأقرب للهدف ثم
/// الأقل تذبذبًا) من التركيبات التي قيست عليها قطع كافية. ويقارن بين المكائن
/// (جودة الأوزان والعيوب والأعطال). مرِّر [fixedMachineId] لتحليل مكينة واحدة
/// فقط (غرفة المكينة)، و[onOpenMachine] لفتح غرفة مكينة من جدول المقارنة.
class MamoulAnalysisTab extends StatefulWidget {
  final String? fixedMachineId;
  final void Function(MamoulMachine machine)? onOpenMachine;

  const MamoulAnalysisTab({super.key, this.fixedMachineId, this.onOpenMachine});

  @override
  State<MamoulAnalysisTab> createState() => _MamoulAnalysisTabState();
}

class _MamoulAnalysisTabState extends State<MamoulAnalysisTab> with AutomaticKeepAliveClientMixin {
  int _days = 90;

  /// null = كل الأهداف.
  double? _target;
  String? _machineFilter;
  bool _showAllSpeeds = false;

  MamoulAnalysis? _analysis;
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
      final a = await MamoulMonitorService.fetchAnalysis(
        from: mamoulFromDays(_days),
        to: mamoulToday(),
        target: _target,
        machineId: _effectiveMachineId,
      );
      if (!mounted || id != _requestId) return;
      setState(() {
        _analysis = a;
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

  // ------------------------------- أدوات عرض -------------------------------

  String _deviationText(double dev) {
    if (dev.abs() < 0.005) return 'على الهدف تمامًا';
    final n = mamoulNum(dev.abs(), decimals: 2);
    return dev > 0 ? 'أعلى من الهدف بـ $n' : 'أقل من الهدف بـ $n';
  }

  Color? _outColor(double? v) {
    if (v == null) return null;
    return v <= 0 ? AppColors.successText : kMamoulDanger;
  }

  /// يجمع المجموعات بحسب المكينة مع الحفاظ على ترتيبها: (معرّف، اسم، مجموعاتها).
  List<MapEntry<String, List<MamoulSpeedGroup>>> _byMachine(List<MamoulSpeedGroup> groups) {
    final order = <String>[];
    final map = <String, List<MamoulSpeedGroup>>{};
    for (final g in groups) {
      final key = g.machineName ?? 'بدون مكينة';
      if (!map.containsKey(key)) {
        order.add(key);
        map[key] = <MamoulSpeedGroup>[];
      }
      map[key]!.add(g);
    }
    return [for (final k in order) MapEntry(k, map[k]!)];
  }

  // ------------------------------- الأقسام -------------------------------

  Widget _recommendedCard(int rank, MamoulSpeedGroup g) {
    final okAll = g.outPct <= 0;
    final badgeColor = rank == 1 ? AppColors.successText : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MamoulCard(
        borderColor: rank == 1 ? AppColors.successText.withOpacity(0.5) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StatusPill(
                  label: rank == 1 ? 'الأفضل' : 'الخيار ${mamoulCount(rank)}',
                  color: badgeColor,
                  background: badgeColor.withOpacity(0.10),
                ),
                const SizedBox(width: 8),
                Text('هدف ${mamoulNum(g.targetWeight)}', style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                const Spacer(),
                StatusPill(
                  label: okAll ? 'كل القطع ضمن النطاق' : 'خارج النطاق ${mamoulPct(g.outPct)}',
                  color: okAll ? AppColors.successText : kMamoulDanger,
                  background: okAll ? AppColors.successBg : kMamoulDanger.withOpacity(0.10),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: MamoulStat(label: 'السير', value: mamoulSpeed(g.speedBelt, g.speedUnit))),
                Expanded(child: MamoulStat(label: 'دفع المعمول', value: mamoulSpeed(g.speedPush, g.speedUnit))),
                Expanded(child: MamoulStat(label: 'الدوار', value: mamoulSpeed(g.speedRotary, g.speedUnit))),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'عند هذه السرعات تراوحت الأوزان بين ${mamoulWeight(g.min)} و${mamoulWeight(g.max)} جرام '
              '(متوسط ${mamoulWeight(g.avg)} — ${_deviationText(g.deviation)}).',
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.6),
            ),
            const SizedBox(height: 8),
            Text(
              '${mamoulCount(g.pieces)} قطعة في ${mamoulCount(g.samplesCount)} عيّنة من ${mamoulCount(g.runsCount)} تشغيلة'
              ' — الانحراف المعياري ${mamoulNum(g.std, decimals: 3)}',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _recommendedSection(MamoulAnalysis a) {
    final groups = _byMachine(a.recommended);
    final showMachineNames = widget.fixedMachineId == null && _machineFilter == null && mamoulMachines.value.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MamoulSectionTitle('أفضل ضبط للسرعات'),
        const SizedBox(height: 4),
        Text(
          'تُقترح التركيبة بعد قياس ${mamoulCount(kMamoulMinPieces)} قطعة عليها على الأقل، ويُرتَّب الأفضل بأقل قطع خارج النطاق ثم الأقرب للهدف.',
          style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.5),
        ),
        const SizedBox(height: 10),
        if (a.recommended.isEmpty)
          const InfoNote(
            text: 'لا توجد بعد تركيبة سرعات قيست عليها قطع كافية. استمر في تسجيل العيّنات بنفس السرعات.',
            color: AppColors.warningText,
            icon: Icons.hourglass_empty,
          )
        else
          for (final entry in groups) ...[
            if (showMachineNames)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 4),
                child: Row(
                  children: [
                    const Icon(Icons.precision_manufacturing_outlined, size: 18, color: kMamoulColor),
                    const SizedBox(width: 6),
                    Text(entry.key, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kMamoulColor)),
                  ],
                ),
              ),
            for (var i = 0; i < entry.value.length; i++) _recommendedCard(i + 1, entry.value[i]),
          ],
      ],
    );
  }

  Widget _groupRow(MamoulSpeedGroup g, bool showMachine) {
    final muted = !g.enoughData;
    final textColor = muted ? AppColors.textMuted : AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${showMachine ? '${g.machineName ?? 'بدون مكينة'} — ' : ''}${mamoulSpeedsLine(g.speedBelt, g.speedPush, g.speedRotary, g.speedUnit)}',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textColor),
          ),
          const SizedBox(height: 3),
          Text(
            'هدف ${mamoulNum(g.targetWeight)} — متوسط ${mamoulWeight(g.avg)} — خارج النطاق ${mamoulPct(g.outPct)}'
            ' — ${mamoulCount(g.pieces)} قطعة${muted ? ' (بيانات قليلة)' : ''}',
            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _allSpeedsSection(MamoulAnalysis a) {
    if (a.speeds.isEmpty) return const SizedBox.shrink();
    final showMachine = widget.fixedMachineId == null && _machineFilter == null && mamoulMachines.value.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MamoulSectionTitle(
          'كل تركيبات السرعات (${mamoulCount(a.speeds.length)})',
          trailing: TextButton(
            onPressed: () => setState(() => _showAllSpeeds = !_showAllSpeeds),
            style: TextButton.styleFrom(foregroundColor: kMamoulColor),
            child: Text(_showAllSpeeds ? 'إخفاء' : 'عرض'),
          ),
        ),
        if (_showAllSpeeds) ...[
          const SizedBox(height: 6),
          MamoulCard(
            child: Column(
              children: [
                for (var i = 0; i < a.speeds.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  _groupRow(a.speeds[i], showMachine),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _groupStatsSection(String title, List<MamoulGroupStat> items, {bool moisture = false}) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MamoulSectionTitle(title),
        const SizedBox(height: 10),
        MamoulCard(
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        moisture ? mamoulMoistureLabel(items[i].label) : items[i].label,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(child: MamoulStat(label: 'المتوسط', value: mamoulWeight(items[i].avg))),
                    Expanded(
                      child: MamoulStat(
                        label: 'خارج النطاق',
                        value: mamoulPct(items[i].outPct),
                        color: _outColor(items[i].outPct),
                      ),
                    ),
                    Expanded(child: MamoulStat(label: 'القطع', value: mamoulCount(items[i].pieces))),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _machineCard(MamoulMachineComparison c) {
    final machine = mamoulMachineById(c.machineId);
    final open = widget.onOpenMachine;
    final canOpen = machine != null && open != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MamoulCard(
        onTap: (machine != null && open != null) ? () => open(machine) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.precision_manufacturing_outlined, size: 19, color: kMamoulColor),
                const SizedBox(width: 8),
                Expanded(child: Text(c.machineName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold))),
                if (!c.active)
                  const StatusPill(label: 'معطّلة', color: AppColors.textSecondary, background: AppColors.divider),
                if (canOpen) const Icon(Icons.chevron_left, color: AppColors.textMuted),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 22,
              runSpacing: 10,
              children: [
                MamoulStat(label: 'التشغيلات', value: mamoulCount(c.runsCount)),
                MamoulStat(label: 'القطع المقاسة', value: mamoulCount(c.pieces)),
                MamoulStat(label: 'متوسط الوزن', value: c.pieces == 0 ? '—' : mamoulWeight(c.avg)),
                MamoulStat(
                  label: 'خارج النطاق',
                  value: c.pieces == 0 ? '—' : mamoulPct(c.outPct),
                  color: c.pieces == 0 ? null : _outColor(c.outPct),
                ),
                MamoulStat(label: 'التذبذب', value: c.pieces == 0 ? '—' : mamoulNum(c.std, decimals: 3)),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                StatusPill(
                  label: 'توائم ${mamoulCount(c.defects.twins)} · زوائد ${mamoulCount(c.defects.flash)} · مرفوض ${mamoulCount(c.defects.rejected)}',
                  color: c.defects.total > 0 ? kMamoulDanger : AppColors.successText,
                  background: c.defects.total > 0 ? kMamoulDanger.withOpacity(0.10) : AppColors.successBg,
                ),
                if (c.defectPct != null)
                  StatusPill(
                    label: 'عيوب ${mamoulPct(c.defectPct)} من الإنتاج',
                    color: kMamoulDanger,
                    background: kMamoulDanger.withOpacity(0.10),
                  ),
                StatusPill(
                  label: 'أعطال ${mamoulCount(c.faultsTotal)}${c.faultsOpen > 0 ? ' (مفتوح ${mamoulCount(c.faultsOpen)})' : ''}',
                  color: c.faultsOpen > 0 ? AppColors.warningText : AppColors.textSecondary,
                  background: c.faultsOpen > 0 ? AppColors.warningBg : AppColors.divider,
                ),
                if (c.downtimeMinutes > 0)
                  StatusPill(
                    label: 'توقف ${mamoulDuration(c.downtimeMinutes)}',
                    color: AppColors.textSecondary,
                    background: AppColors.divider,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _comparisonSection(MamoulAnalysis a) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MamoulSectionTitle('مقارنة بين المكائن'),
        const SizedBox(height: 4),
        const Text(
          'اضغط على مكينة لفتح غرفتها (تحليلها وتشغيلاتها وأعطالها منفردة).',
          style: TextStyle(fontSize: 11.5, color: AppColors.textMuted),
        ),
        const SizedBox(height: 10),
        for (final c in a.machines) _machineCard(c),
      ],
    );
  }

  // ------------------------------- البناء -------------------------------

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final children = <Widget>[];

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
    children.add(MamoulDaysChips(days: _days, onChanged: (d) => _reloadFor(() => _days = d)));
    children.add(const SizedBox(height: 10));
    children.add(
      MamoulChoiceRow<double?>(
        options: <double?>[null, ...kMamoulTargets],
        labelOf: (v) => v == null ? 'كل الأهداف' : 'هدف ${mamoulNum(v)}',
        selected: _target,
        onSelected: (v) => _reloadFor(() => _target = v),
      ),
    );
    children.add(const SizedBox(height: 16));

    final a = _analysis;
    if (_loading && a == null) {
      children.add(const MamoulLoadingView());
    } else if (_error != null && a == null) {
      children.add(MamoulErrorView(message: _error!, onRetry: _load));
    } else if (a != null) {
      final showComparison = widget.fixedMachineId == null && _machineFilter == null && a.machines.isNotEmpty;
      if (showComparison) {
        children.add(_comparisonSection(a));
        children.add(const SizedBox(height: 18));
      }
      if (a.samplesCount == 0) {
        children.add(const MamoulEmptyState(
          icon: Icons.insights_outlined,
          text: 'لا توجد عيّنات أوزان في هذه الفترة.\nسجّل عيّنات داخل التشغيلات، وسيبدأ التحليل بالظهور هنا.',
        ));
      } else {
        children.add(Row(
          children: [
            KpiCard(value: mamoulCount(a.samplesCount), label: 'عيّنات محلَّلة', valueColor: kMamoulColor),
            const SizedBox(width: 10),
            KpiCard(value: mamoulCount(a.speeds.length), label: 'تركيبات سرعات', valueColor: AppColors.maintenance),
            const SizedBox(width: 10),
            KpiCard(
              value: mamoulCount(a.recommended.length),
              label: 'موصى بها',
              valueColor: a.recommended.isEmpty ? AppColors.textMuted : AppColors.successText,
            ),
          ],
        ));
        children.add(const SizedBox(height: 18));
        children.add(_recommendedSection(a));
        children.add(const SizedBox(height: 18));
        children.add(_allSpeedsSection(a));
        if (a.byMoisture.isNotEmpty) {
          children.add(const SizedBox(height: 18));
          children.add(_groupStatsSection('الأوزان حسب رطوبة العجينة', a.byMoisture, moisture: true));
        }
        if (a.byBatch.isNotEmpty) {
          children.add(const SizedBox(height: 18));
          children.add(_groupStatsSection('الأوزان حسب دفعة العجينة', a.byBatch));
        }
      }
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
        children: children,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/mamoul_monitor.dart';
import '../../services/auth_service.dart';
import '../../services/mamoul_monitor_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'mamoul_fault_form_screen.dart';
import 'mamoul_run_form_screen.dart';
import 'mamoul_run_sheets.dart';
import 'mamoul_widgets.dart';

/// شاشة تشغيلة معمول واحدة: بياناتها، السرعات الحالية وسجل تغييرها، عيّنات
/// الأوزان وحكمها (مع القطع/دقيقة وضغط اليد وحرارة العجينة)، العيوب،
/// التدخل البشري، وأعطال هذه التشغيلة. لا تُضاف بيانات لتشغيلة مغلقة
/// (أعد فتحها أولًا). حذف التشغيلة لمسؤول الصيانة ومدير النظام فقط.
class MamoulRunScreen extends StatefulWidget {
  final String runId;

  const MamoulRunScreen({super.key, required this.runId});

  @override
  State<MamoulRunScreen> createState() => _MamoulRunScreenState();
}

class _MamoulRunScreenState extends State<MamoulRunScreen> {
  MamoulRunDetail? _detail;
  bool _loading = true;
  String? _error;
  bool _busy = false;
  int _requestId = 0;

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
    try {
      final d = await MamoulMonitorService.fetchRun(widget.runId);
      if (!mounted || id != _requestId) return;
      setState(() {
        _detail = d;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _loading = false;
        // لو عندنا بيانات معروضة فلا نستبدلها بشاشة خطأ بسبب فشل تحديث عابر.
        if (_detail == null) _error = mamoulErrorText(e);
      });
    }
  }

  bool get _canManage {
    final role = context.read<AuthService>().currentUser?.role;
    return role != null && canManageMaintenance(role);
  }

  // ------------------------------- الإجراءات -------------------------------

  Future<void> _edit(MamoulRun run) async {
    await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => MamoulRunFormScreen(existing: run)),
    );
  }

  Future<void> _delete(MamoulRun run) async {
    final ok = await confirmMamoul(
      context,
      title: 'حذف التشغيلة؟',
      message: 'ستُحذف التشغيلة بكل عيّناتها وعيوبها وتدخلاتها وسجل سرعاتها نهائيًا. هذا لا يمكن التراجع عنه.',
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await MamoulMonitorService.deleteRun(run.id);
      notifyMamoulChanged();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMamoulSnack(context, mamoulErrorText(e), error: true);
    }
  }

  Future<void> _reopen(MamoulRun run) async {
    setState(() => _busy = true);
    try {
      await MamoulMonitorService.reopenRun(run.id);
      notifyMamoulChanged();
      if (!mounted) return;
      setState(() => _busy = false);
      showMamoulSnack(context, 'أُعيد فتح التشغيلة');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      showMamoulSnack(context, mamoulErrorText(e), error: true);
    }
  }

  Future<void> _close(MamoulRun run) async {
    final done = await showMamoulSheet<bool>(context, (ctx) => MamoulCloseSheet(run: run));
    if (done == true && mounted) showMamoulSnack(context, 'أُغلقت التشغيلة');
  }

  Future<void> _addSample(MamoulRun run, {MamoulSample? existing}) async {
    final done = await showMamoulSheet<bool>(context, (ctx) => MamoulSampleSheet(run: run, existing: existing));
    if (done == true && mounted) showMamoulSnack(context, existing == null ? 'سُجّلت العيّنة' : 'حُفظ تعديل العيّنة');
  }

  Future<void> _deleteSample(MamoulSample s) async {
    final ok = await confirmMamoul(
      context,
      title: 'حذف العيّنة؟',
      message: 'ستُحذف عيّنة الساعة ${mamoulTimeLabel(s.time)} بكل أوزانها.',
    );
    if (!ok || !mounted) return;
    try {
      await MamoulMonitorService.deleteSample(s.id);
      notifyMamoulChanged();
    } catch (e) {
      if (!mounted) return;
      showMamoulSnack(context, mamoulErrorText(e), error: true);
    }
  }

  Future<void> _changeSpeeds(MamoulRun run) async {
    final done = await showMamoulSheet<bool>(context, (ctx) => MamoulSpeedSheet(run: run));
    if (done == true && mounted) showMamoulSnack(context, 'سُجّلت السرعات الجديدة');
  }

  Future<void> _addDefects(MamoulRun run) async {
    final done = await showMamoulSheet<bool>(context, (ctx) => MamoulDefectSheet(run: run));
    if (done == true && mounted) showMamoulSnack(context, 'سُجّلت العيوب');
  }

  Future<void> _deleteDefect(MamoulDefectEntry d) async {
    final ok = await confirmMamoul(
      context,
      title: 'حذف تسجيل العيوب؟',
      message: 'سيُحذف تسجيل الساعة ${mamoulTimeLabel(d.time)} من العيوب.',
    );
    if (!ok || !mounted) return;
    try {
      await MamoulMonitorService.deleteDefect(d.id);
      notifyMamoulChanged();
    } catch (e) {
      if (!mounted) return;
      showMamoulSnack(context, mamoulErrorText(e), error: true);
    }
  }

  Future<void> _addIntervention(MamoulRun run) async {
    final done = await showMamoulSheet<bool>(context, (ctx) => MamoulInterventionSheet(run: run));
    if (done == true && mounted) showMamoulSnack(context, 'سُجّل التدخل');
  }

  Future<void> _deleteIntervention(MamoulIntervention x) async {
    final ok = await confirmMamoul(
      context,
      title: 'حذف التدخل؟',
      message: 'سيُحذف تسجيل «${x.label}» الساعة ${mamoulTimeLabel(x.time)}.',
    );
    if (!ok || !mounted) return;
    try {
      await MamoulMonitorService.deleteIntervention(x.id);
      notifyMamoulChanged();
    } catch (e) {
      if (!mounted) return;
      showMamoulSnack(context, mamoulErrorText(e), error: true);
    }
  }

  Future<void> _addFault(MamoulRun run) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => MamoulFaultFormScreen(run: run)),
    );
  }

  Future<void> _openFault(MamoulFault f) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => MamoulFaultFormScreen(existing: f)),
    );
  }

  // ------------------------------- الأقسام -------------------------------

  Widget _header(MamoulRun run) {
    final date = mamoulParseDate(run.runDate);
    final weekday = date == null ? '' : '${mamoulWeekdayName(date)} ';
    final moistureParts = <String>[
      if (run.moistureLevel != null) mamoulMoistureLabel(run.moistureLevel),
      if (run.moisturePct != null) mamoulPct(run.moisturePct),
    ];
    return MamoulCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.precision_manufacturing_outlined, size: 20, color: kMamoulColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(run.machineLabel, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ),
              StatusPill(
                label: run.isOpen ? 'جارية' : 'مغلقة',
                color: run.isOpen ? AppColors.successText : AppColors.textSecondary,
                background: run.isOpen ? AppColors.successBg : AppColors.divider,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('$weekday${mamoulDateLabel(run.runDate)}', style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              MamoulStat(label: 'الوزن المستهدف', value: '${mamoulNum(run.targetWeight)} جم'),
              MamoulStat(label: 'النطاق المقبول', value: '${mamoulNum(run.weightMin)} – ${mamoulNum(run.weightMax)}'),
              if (run.shift != null) MamoulStat(label: 'الوردية', value: run.shift!),
              if (run.startTime != null) MamoulStat(label: 'البدء', value: mamoulTimeLabel(run.startTime!)),
              if (run.endTime != null) MamoulStat(label: 'الانتهاء', value: mamoulTimeLabel(run.endTime!)),
              if (run.operatorName != null) MamoulStat(label: 'المشغّل', value: run.operatorName!),
              if (run.pasteBatch != null) MamoulStat(label: 'دفعة العجينة', value: run.pasteBatch!),
              if (moistureParts.isNotEmpty) MamoulStat(label: 'رطوبة العجينة', value: moistureParts.join(' — ')),
              if (run.producedCount != null) MamoulStat(label: 'المنتَج', value: mamoulCount(run.producedCount!)),
            ],
          ),
          if (run.notes != null) ...[
            const SizedBox(height: 10),
            Text(run.notes!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5)),
          ],
        ],
      ),
    );
  }

  Widget _weightsSummary(MamoulRun run) {
    final s = run.summary;
    final stats = s.stats;
    final lastHint = mamoulTrendHint(s.lastSampleTrend);
    return MamoulCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: MamoulSectionTitle('حالة الأوزان')),
              if (s.lastSampleLevel != null)
                MamoulLevelPill(
                  level: s.lastSampleLevel!,
                  label: 'آخر عيّنة: ${mamoulLevelLabel(s.lastSampleLevel!)}',
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (s.samplesCount == 0)
            const Text(
              'لا عيّنات بعد. خذ قطعًا من الخط، زنها، وسجّل أوزانها بزر «إضافة عيّنة».',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted, height: 1.5),
            )
          else ...[
            Wrap(
              spacing: 24,
              runSpacing: 10,
              children: [
                MamoulStat(label: 'العيّنات', value: mamoulCount(s.samplesCount)),
                MamoulStat(label: 'القطع المقاسة', value: mamoulCount(s.piecesCount)),
                MamoulStat(label: 'المتوسط', value: mamoulWeight(stats.avg), color: mamoulLevelColor(stats.level)),
                MamoulStat(label: 'الانحراف', value: mamoulNum(stats.std, decimals: 3)),
                MamoulStat(label: 'الأقل', value: mamoulWeight(stats.min)),
                MamoulStat(label: 'الأعلى', value: mamoulWeight(stats.max)),
                MamoulStat(
                  label: 'خارج النطاق',
                  value: stats.outCount == 0 ? '٠' : '${mamoulCount(stats.outCount)} (${mamoulPct(stats.outPct)})',
                  color: stats.outCount == 0 ? AppColors.successText : kMamoulDanger,
                ),
                if (s.avgPiecesPerMin != null) MamoulStat(label: 'متوسط القطع/دقيقة', value: mamoulNum(s.avgPiecesPerMin, decimals: 1)),
              ],
            ),
            if (lastHint != null) ...[
              const SizedBox(height: 12),
              InfoNote(text: lastHint, color: AppColors.warningText, icon: Icons.trending_flat),
            ],
          ],
        ],
      ),
    );
  }

  Widget _speedsCard(MamoulRun run) {
    String v(double? x) => mamoulSpeed(x, run.speedUnit);
    return MamoulCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MamoulSectionTitle('السرعات الحالية'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: MamoulStat(label: 'السير', value: v(run.speedBelt))),
              Expanded(child: MamoulStat(label: 'دفع المعمول', value: v(run.speedPush))),
              Expanded(child: MamoulStat(label: 'الدوار', value: v(run.speedRotary))),
            ],
          ),
          if (run.isOpen) ...[
            const SizedBox(height: 12),
            MamoulOutlineButton(label: 'تغيير السرعات', icon: Icons.speed, onPressed: () => _changeSpeeds(run)),
          ],
        ],
      ),
    );
  }

  Widget _sampleCard(MamoulRun run, MamoulSample s) {
    final speedsKnown = s.speedBelt != null || s.speedPush != null || s.speedRotary != null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MamoulCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(mamoulTimeLabel(s.time), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                Text('${mamoulCount(s.weights.length)} قطعة', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                const Spacer(),
                MamoulLevelPill(level: s.stats.level),
              ],
            ),
            const SizedBox(height: 10),
            MamoulWeightChips(weights: s.weights, min: run.weightMin, max: run.weightMax),
            const SizedBox(height: 10),
            Wrap(
              spacing: 22,
              runSpacing: 6,
              children: [
                MamoulStat(label: 'المتوسط', value: mamoulWeight(s.stats.avg), color: mamoulLevelColor(s.stats.level)),
                MamoulStat(label: 'الأقل', value: mamoulWeight(s.stats.min)),
                MamoulStat(label: 'الأعلى', value: mamoulWeight(s.stats.max)),
                if (s.stats.outCount > 0)
                  MamoulStat(label: 'خارج النطاق', value: mamoulCount(s.stats.outCount), color: kMamoulDanger),
              ],
            ),
            if (s.piecesPerMin != null || s.pressureLevel != null || s.doughTemp != null) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 22,
                runSpacing: 6,
                children: [
                  if (s.piecesPerMin != null) MamoulStat(label: 'القطع/دقيقة', value: mamoulNum(s.piecesPerMin, decimals: 1)),
                  if (s.pressureLevel != null)
                    MamoulStat(
                      label: 'ضغط اليد',
                      value: s.pressureLevel == 'none' ? 'بدون' : mamoulPressureLabel(s.pressureLevel),
                      color: (s.pressureLevel == 'none') ? null : AppColors.warningText,
                    ),
                  if (s.doughTemp != null) MamoulStat(label: 'حرارة العجينة', value: mamoulTemp(s.doughTemp)),
                ],
              ),
            ],
            if (speedsKnown) ...[
              const SizedBox(height: 8),
              Text(
                mamoulSpeedsLine(s.speedBelt, s.speedPush, s.speedRotary, run.speedUnit),
                style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
              ),
            ],
            if (s.note != null) ...[
              const SizedBox(height: 6),
              Text(s.note!, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.5)),
            ],
            if (run.isOpen) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: () => _addSample(run, existing: s),
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    label: const Text('تعديل'),
                    style: TextButton.styleFrom(foregroundColor: kMamoulColor),
                  ),
                  TextButton.icon(
                    onPressed: () => _deleteSample(s),
                    icon: const Icon(Icons.delete_outline, size: 17),
                    label: const Text('حذف'),
                    style: TextButton.styleFrom(foregroundColor: kMamoulDanger),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _samplesSection(MamoulRun run, List<MamoulSample> samples) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MamoulSectionTitle('عيّنات الأوزان (${mamoulCount(samples.length)})'),
        const SizedBox(height: 10),
        if (run.isOpen) ...[
          PrimaryButton(label: 'إضافة عيّنة', color: kMamoulColor, icon: Icons.scale_outlined, onPressed: () => _addSample(run)),
          const SizedBox(height: 12),
        ],
        if (samples.isEmpty)
          const MamoulEmptyState(icon: Icons.scale_outlined, text: 'لم تُسجَّل عيّنات في هذه التشغيلة بعد.')
        else
          // الأحدث أولًا (السيرفر يرسلها بترتيب الأقدم أولًا).
          for (final s in samples.reversed) _sampleCard(run, s),
      ],
    );
  }

  Widget _defectsSection(MamoulRun run, List<MamoulDefectEntry> entries) {
    final totals = run.summary.defects;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MamoulSectionTitle('العيوب'),
        const SizedBox(height: 10),
        MamoulCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: MamoulStat(label: 'توائم', value: mamoulCount(totals.twins))),
                  Expanded(child: MamoulStat(label: 'زوائد', value: mamoulCount(totals.flash))),
                  Expanded(child: MamoulStat(label: 'مرفوض', value: mamoulCount(totals.rejected))),
                  Expanded(
                    child: MamoulStat(
                      label: 'الإجمالي',
                      value: mamoulCount(totals.total),
                      color: totals.total > 0 ? kMamoulDanger : null,
                    ),
                  ),
                ],
              ),
              if (totals.pctOfProduced != null) ...[
                const SizedBox(height: 8),
                Text(
                  'نسبة العيوب من الإنتاج: ${mamoulPct(totals.pctOfProduced)}',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
                ),
              ],
              if (run.isOpen) ...[
                const SizedBox(height: 12),
                MamoulOutlineButton(label: 'تسجيل عيوب', icon: Icons.report_gmailerrorred_outlined, onPressed: () => _addDefects(run)),
              ],
            ],
          ),
        ),
        for (final d in entries.reversed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: MamoulCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Text(mamoulTimeLabel(d.time), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      [
                        if (d.twins > 0) 'توائم ${mamoulCount(d.twins)}',
                        if (d.flash > 0) 'زوائد ${mamoulCount(d.flash)}',
                        if (d.rejected > 0) 'مرفوض ${mamoulCount(d.rejected)}',
                        if (d.note != null) '— ${d.note}',
                      ].join('  '),
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.5),
                    ),
                  ),
                  if (run.isOpen)
                    IconButton(
                      tooltip: 'حذف',
                      onPressed: () => _deleteDefect(d),
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: kMamoulDanger,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _interventionsSection(MamoulRun run, List<MamoulIntervention> entries) {
    final s = run.summary;
    final summaryText = entries.isEmpty
        ? 'لم يُسجَّل أي تدخل. سجّل كل مرة يضغط فيها العامل على المكينة أو يتدخل يدويًا، فهذا يُظهر هل المكينة تعطي الوزن وحدها.'
        : (s.interventionsMinutes > 0
            ? 'عدد التدخلات: ${mamoulCount(s.interventionsCount)} — مجموع المدة: ${mamoulDuration(s.interventionsMinutes)}'
            : 'عدد التدخلات: ${mamoulCount(s.interventionsCount)}');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MamoulSectionTitle('التدخل البشري (${mamoulCount(entries.length)})'),
        const SizedBox(height: 10),
        MamoulCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                summaryText,
                style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.5),
              ),
              if (run.isOpen) ...[
                const SizedBox(height: 12),
                MamoulOutlineButton(label: 'تسجيل تدخل بشري', icon: Icons.pan_tool_outlined, onPressed: () => _addIntervention(run)),
              ],
            ],
          ),
        ),
        for (final x in entries.reversed)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: MamoulCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Text(mamoulTimeLabel(x.time), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      [
                        x.label,
                        if (x.minutes != null && x.minutes! > 0) mamoulDuration(x.minutes),
                        if (x.note != null) '— ${x.note}',
                      ].join('  '),
                      style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.5),
                    ),
                  ),
                  if (run.isOpen)
                    IconButton(
                      tooltip: 'حذف',
                      onPressed: () => _deleteIntervention(x),
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: kMamoulDanger,
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _faultsSection(MamoulRun run, List<MamoulFault> faults) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MamoulSectionTitle('أعطال هذه التشغيلة (${mamoulCount(faults.length)})'),
        const SizedBox(height: 10),
        for (final f in faults)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: MamoulCard(
              onTap: () => _openFault(f),
              child: Row(
                children: [
                  Icon(mamoulComponentIcon(f.component), size: 20, color: f.isOpen ? kMamoulDanger : AppColors.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold)),
                        Text(
                          f.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  StatusPill(
                    label: f.isOpen ? 'مفتوح' : 'تم الحل',
                    color: f.isOpen ? kMamoulDanger : AppColors.successText,
                    background: f.isOpen ? kMamoulDanger.withOpacity(0.10) : AppColors.successBg,
                  ),
                ],
              ),
            ),
          ),
        MamoulOutlineButton(label: 'تسجيل عطل في هذه التشغيلة', icon: Icons.build_circle_outlined, onPressed: () => _addFault(run)),
      ],
    );
  }

  Widget _speedHistory(MamoulRun run, List<MamoulSpeedChange> changes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MamoulSectionTitle('سجل السرعات'),
        const SizedBox(height: 10),
        MamoulCard(
          child: Column(
            children: [
              for (var i = 0; i < changes.length; i++) ...[
                if (i > 0) const Divider(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 52,
                      child: Text(mamoulTimeLabel(changes[i].time), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            mamoulSpeedsLine(changes[i].belt, changes[i].push, changes[i].rotary, run.speedUnit),
                            style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                          ),
                          if (changes[i].reason != null)
                            Text(changes[i].reason!, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted, height: 1.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final run = detail?.run;

    final actions = <Widget>[
      if (run != null)
        IconButton(
          tooltip: 'تعديل بيانات التشغيلة',
          onPressed: _busy ? null : () => _edit(run),
          icon: const Icon(Icons.edit_outlined),
        ),
      if (run != null && _canManage)
        IconButton(
          tooltip: 'حذف التشغيلة',
          onPressed: _busy ? null : () => _delete(run),
          icon: const Icon(Icons.delete_outline),
          color: kMamoulDanger,
        ),
    ];

    Widget body;
    if (_loading && detail == null) {
      body = const MamoulLoadingView();
    } else if (detail == null) {
      body = MamoulErrorView(
        message: _error ?? 'تعذّر تحميل التشغيلة',
        onRetry: () {
          setState(() {
            _loading = true;
            _error = null;
          });
          _load();
        },
      );
    } else {
      final r = detail.run;
      body = ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _header(r),
          const SizedBox(height: 12),
          _weightsSummary(r),
          const SizedBox(height: 12),
          _speedsCard(r),
          const SizedBox(height: 18),
          _samplesSection(r, detail.samples),
          const SizedBox(height: 18),
          _defectsSection(r, detail.defects),
          const SizedBox(height: 18),
          _interventionsSection(r, detail.interventions),
          const SizedBox(height: 18),
          _faultsSection(r, detail.faults),
          if (detail.speedChanges.isNotEmpty) ...[
            const SizedBox(height: 18),
            _speedHistory(r, detail.speedChanges),
          ],
          const SizedBox(height: 22),
          if (r.isOpen)
            PrimaryButton(
              label: _busy ? 'لحظة...' : 'إغلاق التشغيلة',
              color: kMamoulColor,
              icon: Icons.lock_outline,
              onPressed: _busy ? null : () => _close(r),
            )
          else
            MamoulOutlineButton(
              label: _busy ? 'لحظة...' : 'إعادة فتح التشغيلة',
              icon: Icons.lock_open_outlined,
              onPressed: _busy ? null : () => _reopen(r),
            ),
        ],
      );
    }

    return Scaffold(
      appBar: ScreenTopBar(title: 'تشغيلة المعمول', actions: actions),
      body: SafeArea(child: RefreshIndicator(onRefresh: _load, child: body)),
    );
  }
}

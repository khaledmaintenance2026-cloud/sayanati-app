import 'package:flutter/material.dart';

import '../../models/mamoul_monitor.dart';
import '../../models/mamoul_op_report.dart';
import '../../services/mamoul_op_report_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'mamoul_op_report_form_screen.dart';
import 'mamoul_op_report_screen.dart';
import 'mamoul_signature_screen.dart';
import 'mamoul_widgets.dart';
import 'mamoul_workers_screen.dart';

/// تبويب «تقارير التشغيل» داخل أداة المعمول: النسخة الإلكترونية من ورقة
/// Mamoul Operating Report (QMS-PD-006). تقارير كل يوم (حسب تاريخ تكوير
/// الكرات)، بحث برقم الدفعة، قائمة العاملات، التوقيع الجاهز، وطباعة كل تقرير
/// بنفس شكل الورقة. الصلاحيات تأتي من السيرفر (can_write / can_manage).
class MamoulOpReportsTab extends StatefulWidget {
  const MamoulOpReportsTab({super.key});

  @override
  State<MamoulOpReportsTab> createState() => _MamoulOpReportsTabState();
}

class _MamoulOpReportsTabState extends State<MamoulOpReportsTab> with AutomaticKeepAliveClientMixin {
  late DateTime _day;
  MamoulOpConfig? _config;
  MamoulOpReportsResult? _result;
  bool _loading = true;
  String? _error;
  int _requestId = 0;
  final TextEditingController _search = TextEditingController();
  String? _searchTerm;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _day = DateTime(now.year, now.month, now.day);
    mamoulOpChanged.addListener(_onChanged);
    _load();
  }

  @override
  void dispose() {
    mamoulOpChanged.removeListener(_onChanged);
    _search.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final id = ++_requestId;
    if (mounted) setState(() => _error = null);
    try {
      final term = _searchTerm;
      final config = await MamoulOpReportService.fetchConfig();
      final result = term == null
          ? await MamoulOpReportService.fetchReportsOfDay(mamoulIsoDate(_day))
          : await MamoulOpReportService.searchReports(term);
      if (!mounted || id != _requestId) return;
      setState(() {
        _config = config;
        _result = result;
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

  void _runSearch(String raw) {
    final term = raw.trim();
    setState(() {
      _searchTerm = term.isEmpty ? null : term;
      _result = null;
      _loading = true;
    });
    _load();
  }

  void _clearSearch() {
    _search.clear();
    FocusScope.of(context).unfocus();
    _runSearch('');
  }

  Future<void> _newReport() async {
    final config = _config;
    if (config == null) return;
    final id = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => MamoulOpReportFormScreen(config: config, initialDate: _day)),
    );
    if (id != null && mounted) _open(id);
  }

  Future<void> _open(String id) async {
    final config = _config;
    if (config == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => MamoulOpReportScreen(reportId: id, config: config)),
    );
  }

  void _openWorkers() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => MamoulWorkersScreen(canWrite: _config?.canWrite ?? false)),
    );
  }

  Future<void> _openSignature() async {
    final config = _config;
    if (config == null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => MamoulSignatureScreen(config: config)),
    );
    if (saved == true && mounted) _load();
  }

  // ------------------------------ بناء الواجهة ------------------------------

  Widget _reportCard(MamoulOpReport r) {
    final times = <String>[
      if (r.startTime != null) mamoulTimeLabel(r.startTime!),
      if (r.endTime != null) mamoulTimeLabel(r.endTime!),
    ].join(' – ');
    final line = <String>[
      r.productName,
      if (_searchTerm != null) mamoulDateLabel(r.ballMakeDate),
      if (times.isNotEmpty) times,
    ].join(' — ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: MamoulCard(
        onTap: () => _open(r.id),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.description_outlined, size: 19, color: kMamoulColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'دفعة ${r.batchNo}',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                if (r.hasSignature)
                  const StatusPill(label: 'موقّع', color: AppColors.successText, background: AppColors.successBg),
              ],
            ),
            const SizedBox(height: 4),
            Text(line, style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: MamoulStat(label: 'وزن الدفعة', value: mamoulGramsText(r.batchWeightG))),
                Expanded(child: MamoulStat(label: 'العاملات', value: mamoulCount(r.workersCount))),
                Expanded(child: MamoulStat(label: 'المكائن', value: r.machinesLine)),
              ],
            ),
            if (r.operatorName != null) ...[
              const SizedBox(height: 8),
              Text('المشغّلة: ${r.operatorName}', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final config = _config;
    final children = <Widget>[];

    if (_searchTerm == null) {
      children.add(MamoulPeriodBar(
        title: mamoulDateLabel(mamoulIsoDate(_day)),
        subtitle: '${mamoulWeekdayName(_day)}${_isToday ? ' — اليوم' : ''}',
        onPrevious: () => _shift(-1),
        onNext: () => _shift(1),
        onTap: _pickDate,
      ));
      children.add(const SizedBox(height: 10));
    }

    children.add(TextField(
      controller: _search,
      textInputAction: TextInputAction.search,
      onSubmitted: _runSearch,
      decoration: fieldDecoration(hint: 'بحث برقم الدفعة').copyWith(
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _searchTerm == null
            ? IconButton(
                tooltip: 'بحث',
                icon: const Icon(Icons.check, size: 20),
                onPressed: () => _runSearch(_search.text),
              )
            : IconButton(tooltip: 'إلغاء البحث', icon: const Icon(Icons.close, size: 20), onPressed: _clearSearch),
      ),
    ));
    children.add(const SizedBox(height: 10));

    children.add(Row(
      children: [
        Expanded(
          child: MamoulOutlineButton(
            label: 'العاملات',
            icon: Icons.groups_outlined,
            onPressed: config == null ? null : _openWorkers,
          ),
        ),
        if (config != null && config.canManage) ...[
          const SizedBox(width: 10),
          Expanded(
            child: MamoulOutlineButton(
              label: 'التوقيع',
              icon: Icons.draw_outlined,
              onPressed: _openSignature,
            ),
          ),
        ],
      ],
    ));
    children.add(const SizedBox(height: 12));

    if (_searchTerm != null) {
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          'نتائج البحث عن «$_searchTerm»',
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
        ),
      ));
    }

    final result = _result;
    if (_loading && result == null) {
      children.add(const MamoulLoadingView());
    } else if (_error != null && result == null) {
      children.add(MamoulErrorView(message: _error!, onRetry: _load));
    } else if (result != null) {
      if (result.reports.isEmpty) {
        children.add(MamoulEmptyState(
          icon: Icons.description_outlined,
          text: _searchTerm != null
              ? 'لا يوجد تقرير بهذا الرقم.'
              : (config != null && config.canWrite
                  ? 'لا توجد تقارير تشغيل في هذا اليوم.\nاضغطي «تقرير جديد» لإدخال ورقة Mamoul Operating Report.'
                  : 'لا توجد تقارير تشغيل في هذا اليوم.'),
        ));
      } else {
        children.add(Row(
          children: [
            KpiCard(value: mamoulCount(result.count), label: 'تقارير', valueColor: kMamoulColor),
            const SizedBox(width: 10),
            KpiCard(
              value: result.weightG > 0 ? mamoulKgText(result.weightG) : '—',
              label: 'مجموع أوزان الدفعات',
              valueColor: AppColors.successText,
            ),
          ],
        ));
        children.add(const SizedBox(height: 14));
        for (final r in result.reports) {
          children.add(_reportCard(r));
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
        if (config != null && config.canWrite)
          Positioned(
            bottom: 20,
            left: 20,
            child: FloatingActionButton.extended(
              heroTag: 'mamoul_new_op_report',
              backgroundColor: kMamoulColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              onPressed: _newReport,
              icon: const Icon(Icons.add),
              label: const Text('تقرير جديد', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
      ],
    );
  }
}

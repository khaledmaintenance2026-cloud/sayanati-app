import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/injury_report.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'injury_report_detail_screen.dart';
import 'injury_report_form_screen.dart';

/// محتوى تبويب "إصابات العمل" داخل شاشة السلامة (راجع safety_home_screen.dart
/// الذي يضم هذا التبويب وتبويب تصاريح العمل معًا تحت شريط تبويبات واحد، بنفس
/// أسلوب AdminHomeScreen) — بلا Scaffold/AppBar خاص به لأنه يُعرض كمحتوى
/// TabBarView. القائمة مقيَّدة تلقائيًا بقسم مسؤول السلامة الحالي من السيرفر
/// (راجع routes/injuryReports.js).
class InjuryReportsListScreen extends StatefulWidget {
  const InjuryReportsListScreen({super.key});

  @override
  State<InjuryReportsListScreen> createState() => _InjuryReportsListScreenState();
}

class _InjuryReportsListScreenState extends State<InjuryReportsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<AppState>().reloadInjuryReports());
  }

  Future<void> _openNew() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const InjuryReportFormScreen()),
    );
    if (saved == true && mounted) context.read<AppState>().reloadInjuryReports();
  }

  Future<void> _openDetail(InjuryReport report) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => InjuryReportDetailScreen(reportId: report.id)),
    );
    if (mounted) context.read<AppState>().reloadInjuryReports();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerRight,
                  child: Text('تقارير تحقيق الإصابات', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => state.reloadInjuryReports(),
                    child: !state.injuryReportsLoaded && state.injuryReportsError == null
                        ? const Center(child: CircularProgressIndicator())
                        : state.injuryReportsError != null && state.injuryReports.isEmpty
                            ? ListView(
                                children: [
                                  const SizedBox(height: 60),
                                  Center(
                                    child: Text(state.injuryReportsError!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted)),
                                  ),
                                ],
                              )
                            : state.injuryReports.isEmpty
                                ? ListView(
                                    children: const [
                                      SizedBox(height: 60),
                                      Center(child: Text('لا توجد تقارير إصابات عمل', style: TextStyle(color: AppColors.textMuted))),
                                    ],
                                  )
                                : ListView.separated(
                                    itemCount: state.injuryReports.length,
                                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                                    itemBuilder: (context, i) {
                                      final report = state.injuryReports[i];
                                      return _ReportCard(report: report, onTap: () => _openDetail(report));
                                    },
                                  ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            child: FloatingActionButton(
              backgroundColor: AppColors.safety,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              onPressed: _openNew,
              child: const Icon(Icons.add, color: AppColors.safetyText),
            ),
          ),
        ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  final InjuryReport report;
  final VoidCallback onTap;
  const _ReportCard({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final closed = report.isClosed;
    final statusInfo = closed
        ? (label: 'مُغلَق', color: AppColors.successText, bg: AppColors.successBg)
        : (label: 'مفتوح', color: AppColors.warningText, bg: AppColors.warningBg);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    report.incidentNumber != null && report.incidentNumber!.isNotEmpty ? report.incidentNumber! : 'حادث بدون رقم',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
                StatusPill(label: statusInfo.label, color: statusInfo.color, background: statusInfo.bg),
              ],
            ),
            const SizedBox(height: 6),
            Text(report.incidentLocation, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Text('القسم: ${report.department}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            Text('عدد المصابين: ${report.injuredCount}${report.fatalitiesCount > 0 ? ' (وفيات: ${report.fatalitiesCount})' : ''}',
                style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
            if (report.natureOfAccident.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(multiLabel(kNatureOfAccidentLabels, report.natureOfAccident), style: const TextStyle(fontSize: 11.5, color: AppColors.safetyText)),
              ),
          ],
        ),
      ),
    );
  }
}

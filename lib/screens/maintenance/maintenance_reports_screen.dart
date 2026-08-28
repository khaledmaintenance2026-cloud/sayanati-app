import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class MaintenanceReportsScreen extends StatelessWidget {
  const MaintenanceReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      appBar: const ScreenTopBar(title: 'تقارير الصيانة'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: ListView(
          children: [
            Row(
              children: const [
                KpiCard(value: '٤٧', label: 'إجمالي البلاغات', valueColor: AppColors.maintenance),
                SizedBox(width: 10),
                KpiCard(value: '٣٩ د', label: 'متوسط وقت الإصلاح', valueColor: AppColors.maintenance),
                SizedBox(width: 10),
                KpiCard(value: '١٤', label: 'وقائي منجز', valueColor: AppColors.production),
              ],
            ),
            const SizedBox(height: 20),
            const Text('تقارير تلقائية', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            const _ReportRow(title: 'التقرير الشهري', subtitle: 'PDF — أول كل شهر لجروب الصيانة'),
            const SizedBox(height: 10),
            const _ReportRow(title: 'التقرير السنوي', subtitle: 'PDF — نهاية كل عام'),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(18)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('طلب تقرير بمدة مخصصة', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const InfoNote(text: 'سيصلك ملف PDF على رقمك فقط — لن يُرسل للجروب', color: AppColors.maintenance, icon: Icons.lock_outline),
                  const SizedBox(height: 14),
                  PrimaryButton(
                    label: 'إنشاء التقرير',
                    color: AppColors.maintenance,
                    icon: Icons.file_download_outlined,
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('سيصلك ملف PDF على رقمك خلال دقائق')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text('آخر الأنشطة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            if (state.activityLog.isEmpty)
              const Text('لا يوجد نشاط بعد', style: TextStyle(fontSize: 13, color: AppColors.textMuted))
            else
              ...state.activityLog.take(8).map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(e, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.6)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  final String title;
  final String subtitle;
  const _ReportRow({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: AppColors.maintenance.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.description_outlined, color: AppColors.maintenance),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

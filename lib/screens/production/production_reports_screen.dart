import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state.dart';
import '../../services/arabic_format.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class ProductionReportsScreen extends StatelessWidget {
  const ProductionReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final totalToday = state.batches.fold<int>(0, (sum, b) => sum + b.quantity);
    final activeLines = state.productionLines.where((l) => l.activeToday).length;

    return Scaffold(
      appBar: const ScreenTopBar(title: 'تقارير الإنتاج'),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: ListView(
          children: [
            Row(
              children: [
                KpiCard(value: ArabicFormat.number(totalToday), label: 'إجمالي الإنتاج اليوم', valueColor: AppColors.production),
                const SizedBox(width: 10),
                KpiCard(value: ArabicFormat.number(state.batches.length), label: 'باتشات اليوم', valueColor: AppColors.production),
                const SizedBox(width: 10),
                KpiCard(value: '${ArabicFormat.number(activeLines)}/٦', label: 'خطوط نشطة اليوم', valueColor: AppColors.production),
              ],
            ),
            const SizedBox(height: 20),
            const Text('تقارير تلقائية', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            const _ReportRow(title: 'التقرير الأسبوعي', subtitle: 'PDF — كل نهاية أسبوع لجروب الإنتاج'),
            const SizedBox(height: 10),
            const _ReportRow(title: 'التقرير الشهري', subtitle: 'PDF — أول كل شهر، الكمية والباتشات لكل خط'),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(18)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('طلب تقرير بمدة مخصصة', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const InfoNote(text: 'سيصلك ملف PDF على رقمك فقط — لن يُرسل للجروب', color: AppColors.production, icon: Icons.lock_outline),
                  const SizedBox(height: 14),
                  PrimaryButton(
                    label: 'إنشاء التقرير',
                    color: AppColors.production,
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
            const Text('باتشات اليوم', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            if (state.batches.isEmpty)
              const Text('لا توجد باتشات مسجّلة اليوم', style: TextStyle(fontSize: 13, color: AppColors.textMuted))
            else
              ...state.batches.map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(child: Text('${state.lineById(b.lineId).name} — ${b.productName}', style: const TextStyle(fontSize: 13))),
                      Text(ArabicFormat.number(b.quantity), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.production)),
                    ],
                  ),
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
            decoration: BoxDecoration(color: AppColors.production.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: const Icon(Icons.description_outlined, color: AppColors.production),
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

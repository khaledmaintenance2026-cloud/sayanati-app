import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state.dart';
import '../../services/arabic_format.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// تقرير إنتاج مستقل تمامًا لكل قسم/مصنع على حِدة — يُفتح من تبويب القسم
/// نفسه في شاشة الإنتاج، فلا تختلط بيانات "مصنع الرجال" مع "مصنع النساء".
///
/// الباتشات أصبحت محفوظة على السيرفر (راجع app_state.dart) بدل كونها محلية
/// فقط على جهاز المشرف، لذا نعيد تحميلها عند فتح الشاشة تمامًا مثل خطوط
/// الإنتاج والبلاغات.
class ProductionReportsScreen extends StatefulWidget {
  final String facility;
  const ProductionReportsScreen({super.key, required this.facility});

  @override
  State<ProductionReportsScreen> createState() => _ProductionReportsScreenState();
}

class _ProductionReportsScreenState extends State<ProductionReportsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<AppState>().reloadBatches());
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lines = state.linesByFacility(widget.facility);
    final batches = state.batchesByFacility(widget.facility);
    final totalToday = batches.fold<int>(0, (sum, b) => sum + b.quantity);
    final activeLines = lines.where((l) => l.activeToday).length;

    return Scaffold(
      appBar: ScreenTopBar(title: 'تقارير ${widget.facility}'),
      body: RefreshIndicator(
        onRefresh: () => state.reloadBatches(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: ListView(
            children: [
              Row(
                children: [
                  KpiCard(value: ArabicFormat.number(totalToday), label: 'إجمالي الإنتاج اليوم', valueColor: AppColors.production),
                  const SizedBox(width: 10),
                  KpiCard(value: ArabicFormat.number(batches.length), label: 'باتشات اليوم', valueColor: AppColors.production),
                  const SizedBox(width: 10),
                  KpiCard(value: '${ArabicFormat.number(activeLines)}/${ArabicFormat.number(lines.length)}', label: 'خطوط نشطة اليوم', valueColor: AppColors.production),
                ],
              ),
              const SizedBox(height: 20),
              const Text('تقارير تلقائية', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              _ReportRow(title: 'التقرير الأسبوعي', subtitle: 'PDF — كل نهاية أسبوع لجروب ${widget.facility}'),
              const SizedBox(height: 10),
              _ReportRow(title: 'التقرير الشهري', subtitle: 'PDF — أول كل شهر، الكمية والباتشات لكل خط في ${widget.facility}'),
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
              Text('باتشات ${widget.facility} اليوم', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              if (state.batchesError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: InfoNote(text: state.batchesError!, color: const Color(0xFFB3261E), icon: Icons.error_outline),
                ),
              if (!state.batchesLoaded && state.batchesError == null)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (batches.isEmpty)
                const Text('لا توجد باتشات مسجّلة اليوم', style: TextStyle(fontSize: 13, color: AppColors.textMuted))
              else
                ...batches.map(
                  (b) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(12)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text('${state.lineById(b.lineId).name} — ${b.productName}', style: const TextStyle(fontSize: 13))),
                              Text(ArabicFormat.number(b.quantity), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.production)),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text('باتش رقم: ${b.batchNumber}', style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
                          if ((b.operationalNotes?.isNotEmpty ?? false) || (b.hasStoppage && (b.actionsTaken?.isNotEmpty ?? false))) ...[
                            const SizedBox(height: 6),
                            if (b.operationalNotes?.isNotEmpty ?? false)
                              Text('ملاحظات تشغيلية: ${b.operationalNotes}', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                            if (b.hasStoppage && (b.actionsTaken?.isNotEmpty ?? false))
                              Text('الإجراءات المتخذة: ${b.actionsTaken}', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
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

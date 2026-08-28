import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state.dart';
import '../../services/arabic_format.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'production_batch_form_screen.dart';
import 'production_reports_screen.dart';

class ProductionLinesScreen extends StatelessWidget {
  const ProductionLinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('الإنتاج', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.description_outlined),
            tooltip: 'التقارير',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProductionReportsScreen()),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Align(
              alignment: Alignment.centerRight,
              child: Text('خطوط الإنتاج', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 4),
            const Align(
              alignment: Alignment.centerRight,
              child: Text('اختر الخط لتسجيل باتش جديد', style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.separated(
                itemCount: state.productionLines.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final line = state.productionLines[i];
                  final total = state.lineTotalToday(line.id);
                  final batchCount = state.batches.where((b) => b.lineId == line.id).length;
                  return InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ProductionBatchFormScreen(line: line)),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(16)),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(color: AppColors.production.withOpacity(0.1), borderRadius: BorderRadius.circular(13)),
                            alignment: Alignment.center,
                            child: Text(line.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.production)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(line.activeToday ? 'نشط' : 'متوقف', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: line.activeToday ? AppColors.textPrimary : AppColors.textMuted)),
                                Text('${ArabicFormat.number(batchCount)} باتش اليوم', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                              ],
                            ),
                          ),
                          Text(ArabicFormat.number(total), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.production)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

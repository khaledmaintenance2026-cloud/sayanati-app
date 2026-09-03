import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/production.dart';
import '../../services/app_state.dart';
import '../../services/arabic_format.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'production_batch_form_screen.dart';
import 'production_reports_screen.dart';

class ProductionLinesScreen extends StatelessWidget {
  const ProductionLinesScreen({super.key});

  Future<void> _openForm(BuildContext context, {ProductionLine? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final locationCtrl = TextEditingController(text: existing?.location ?? '');
    final appState = context.read<AppState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          decoration: const BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(existing == null ? 'إضافة خط إنتاج جديد' : 'تعديل خط الإنتاج',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Align(alignment: Alignment.centerRight, child: Text('اسم الخط', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              const SizedBox(height: 6),
              TextField(controller: nameCtrl, decoration: _decoration(hint: 'مثال: خط ١٠')),
              const SizedBox(height: 12),
              const Align(alignment: Alignment.centerRight, child: Text('الموقع (اختياري)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
              const SizedBox(height: 6),
              TextField(controller: locationCtrl, decoration: _decoration(hint: 'مثال: مصنع الرجال')),
              const SizedBox(height: 18),
              PrimaryButton(
                label: existing == null ? 'إضافة الخط' : 'حفظ التعديلات',
                color: AppColors.production,
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final location = locationCtrl.text.trim();
                  if (name.isEmpty) return;
                  if (existing == null) {
                    await appState.addProductionLineCloud(name: name, location: location.isEmpty ? null : location);
                  } else {
                    await appState.updateProductionLineCloud(existing.id, name: name, location: location);
                  }
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, ProductionLine line) async {
    final appState = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف خط الإنتاج؟'),
        content: Text('سيُحذف "${line.name}" نهائيًا. البلاغات والمعدات المرتبطة به تبقى لكن بدون ربط بخط.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('حذف', style: TextStyle(color: Color(0xFFB3261E)))),
        ],
      ),
    );
    if (ok == true) await appState.removeProductionLineCloud(line.id);
  }

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
      body: Stack(
        children: [
          Padding(
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
                  child: Text('اضغط على الخط لتسجيل باتش جديد، أو أيقونتي التعديل/الحذف لإدارته', style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                ),
                const SizedBox(height: 14),
                if (state.productionLinesError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: InfoNote(text: state.productionLinesError!, color: const Color(0xFFB3261E), icon: Icons.error_outline),
                  ),
                Expanded(
                  child: !state.productionLinesLoaded && state.productionLinesError == null
                      ? const Center(child: CircularProgressIndicator())
                      : state.productionLines.isEmpty
                          ? const Center(child: Text('لا توجد خطوط إنتاج بعد — اضغط + للإضافة', style: TextStyle(color: AppColors.textMuted)))
                          : ListView.separated(
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
                                          child: Text(line.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.production), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(line.activeToday ? 'نشط' : 'متوقف', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: line.activeToday ? AppColors.textPrimary : AppColors.textMuted)),
                                              Text('${line.location} · ${ArabicFormat.number(batchCount)} باتش اليوم', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                            ],
                                          ),
                                        ),
                                        Text(ArabicFormat.number(total), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.production)),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 19, color: AppColors.textMuted),
                                          onPressed: () => _openForm(context, existing: line),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 19, color: Color(0xFFB3261E)),
                                          onPressed: () => _confirmDelete(context, line),
                                        ),
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
          Positioned(
            bottom: 20,
            left: 20,
            child: FloatingActionButton(
              backgroundColor: AppColors.production,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              onPressed: () => _openForm(context),
              child: const Icon(Icons.add, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

InputDecoration _decoration({String? hint}) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.background,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.border)),
  );
}

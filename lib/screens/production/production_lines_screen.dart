import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/production.dart';
import '../../services/app_state.dart';
import '../../services/arabic_format.dart';
import '../../services/auth_service.dart';
import '../../services/constants.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import 'production_batch_form_screen.dart';
import 'production_incidents_screen.dart';
import 'production_reports_screen.dart';

/// ترتيب تبويبات الإنتاج: القسمان المطلوبان أولًا (مصنع الرجال/النساء) ثم
/// "المستودع العام" لخطوط قديمة بلا تصنيف. القيم نفسها المسموحة في
/// kFacilityLocations (services/constants.dart) وبنفس القيد على السيرفر
/// (عمود location في جدول production_lines، راجع schema.sql).
const List<String> _kProductionTabs = ['مصنع الرجال', 'مصنع النساء', 'المستودع العام'];

/// شاشة الإنتاج — مقسّمة إلى تبويبين إداريّين منفصلين تمامًا: "مصنع الرجال"
/// و"مصنع النساء" (والتبويب الثالث "المستودع العام" لخطوط قديمة بلا تصنيف)،
/// حسب موقع كل خط (نفس عمود location المخزَّن على السيرفر). كل تبويب له
/// بلاغاته وتقاريره الخاصة به بشكل مستقل عن التبويب الآخر.
class ProductionLinesScreen extends StatefulWidget {
  const ProductionLinesScreen({super.key});

  @override
  State<ProductionLinesScreen> createState() => _ProductionLinesScreenState();
}

class _ProductionLinesScreenState extends State<ProductionLinesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// التبويبات الظاهرة فعليًا لهذا المستخدم — كل التبويبات لمدير النظام أو
  /// أي دور غير مقيَّد، أو تبويب واحد فقط لمستخدم إنتاج مُخصَّص له مصنع
  /// محدد من لوحة الإدارة (لا يمكنه حتى رؤية القسم الآخر، فضلًا عن الدخول
  /// إليه — نفس التقييد مطبَّق فعليًا على السيرفر أيضًا).
  late final List<String> _visibleTabs;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    final restrictedFacility =
        (user != null && user.role == AppRole.production && user.productionFacility != null)
            ? user.productionFacility
            : null;
    _visibleTabs = restrictedFacility != null ? [restrictedFacility] : _kProductionTabs;
    _tabController = TabController(length: _visibleTabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _currentFacility => _visibleTabs[_tabController.index];

  Future<void> _openForm(BuildContext context, {ProductionLine? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    String selectedFacility = existing?.location ?? _currentFacility;
    final appState = context.read<AppState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
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
                const Align(alignment: Alignment.centerRight, child: Text('القسم / المصنع', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                const SizedBox(height: 6),
                if (_visibleTabs.length == 1)
                  // مستخدم مقيَّد بمصنع واحد — لا داعي لإظهار اختيار، الخط
                  // يُضاف مباشرة لمصنعه ولا يمكنه نقله لمصنع آخر أصلًا.
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(selectedFacility, style: const TextStyle(fontWeight: FontWeight.w600)),
                  )
                else
                  DropdownButtonFormField<String>(
                    value: selectedFacility,
                    decoration: _decoration(),
                    items: kFacilityLocations
                        .map((f) => DropdownMenuItem(value: f, child: Text(f)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setSheetState(() => selectedFacility = v);
                    },
                  ),
                const SizedBox(height: 18),
                PrimaryButton(
                  label: existing == null ? 'إضافة الخط' : 'حفظ التعديلات',
                  color: AppColors.production,
                  onPressed: () async {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    if (existing == null) {
                      await appState.addProductionLineCloud(name: name, location: selectedFacility);
                    } else {
                      await appState.updateProductionLineCloud(existing.id, name: name, location: selectedFacility);
                    }
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإنتاج', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.report_problem_outlined),
            tooltip: 'بلاغ عطل',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ProductionIncidentsScreen(facility: _currentFacility)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.description_outlined),
            tooltip: 'التقارير',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ProductionReportsScreen(facility: _currentFacility)),
            ),
          ),
        ],
        bottom: _visibleTabs.length > 1
            ? TabBar(
                controller: _tabController,
                onTap: (_) => setState(() {}),
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                tabs: _visibleTabs.map((f) => Tab(text: f)).toList(),
              )
            : null,
      ),
      body: TabBarView(
        controller: _tabController,
        children: _visibleTabs.map((f) => _FacilityLinesView(
              facility: f,
              onOpenForm: (existing) => _openForm(context, existing: existing),
              onDelete: (line) => _confirmDelete(context, line),
            )).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.production,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        onPressed: () => _openForm(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

class _FacilityLinesView extends StatelessWidget {
  final String facility;
  final void Function(ProductionLine? existing) onOpenForm;
  final void Function(ProductionLine line) onDelete;

  const _FacilityLinesView({
    required this.facility,
    required this.onOpenForm,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lines = state.linesByFacility(facility);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 90),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text('خطوط $facility', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
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
                : lines.isEmpty
                    ? const Center(child: Text('لا توجد خطوط في هذا القسم بعد — اضغط + للإضافة', style: TextStyle(color: AppColors.textMuted)))
                    : ListView.separated(
                        itemCount: lines.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final line = lines[i];
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
                                        Text('${ArabicFormat.number(batchCount)} باتش اليوم', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                      ],
                                    ),
                                  ),
                                  Text(ArabicFormat.number(total), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.production)),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 19, color: AppColors.textMuted),
                                    onPressed: () => onOpenForm(line),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, size: 19, color: Color(0xFFB3261E)),
                                    onPressed: () => onDelete(line),
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

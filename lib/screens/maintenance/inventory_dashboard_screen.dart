import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/api_client.dart';
import '../../services/constants.dart';
import '../../theme/app_theme.dart';
import 'inventory_movements_screen.dart';
import 'inventory_quick_movement_sheet.dart';
import 'inventory_screen.dart';
import 'inventory_suppliers_screen.dart';
import 'inventory_work_sites_screen.dart';

/// الحاوية المستقلة لقسم "المخزون والقطع" — تبويب قائم بذاته بالتنقل السفلي
/// (راجع main.dart وhome_screen.dart)، منفصل تمامًا عن لوحة الصيانة
/// (maintenance_dashboard_screen.dart) رغم أن الوصول له يبقى مقصورًا على
/// فريق الصيانة والمخزون فقط (فني/مسؤول صيانة، مسؤول المخزون، المصمم) —
/// قرار صريح من الإدارة. المحتوى الفعلي كله داخل [InventorySection]
/// (inventory_screen.dart) القابل للتضمين أصلًا؛ هذه الشاشة تضيف فقط
/// Scaffold/AppBar مستقلين بهوية بصرية خاصة (AppColors.inventory) بدل
/// الاعتماد على AppBar لوحة الصيانة كما كان سابقًا، بالإضافة لقائمة "المزيد"
/// التي تفتح الشاشات الفرعية الثلاث (سجل الحركة، الموردون، مواقع العمل)
/// وخيار تصدير CSV.
class InventoryDashboardScreen extends StatelessWidget {
  const InventoryDashboardScreen({super.key});

  Future<void> _exportCsv(BuildContext context, String type) async {
    final token = ApiClient.instance.token;
    if (token == null) return;
    final uri = Uri.parse('$kApiBaseUrl/inventory/export.csv').replace(queryParameters: {'type': type, 'token': token});
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذّر فتح رابط التصدير')));
    }
  }

  Future<void> _openExportDialog(BuildContext context) async {
    final type = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تصدير المخزون (CSV)'),
        content: const Text('يفتح الملف في متصفح خارجي ليقدر يُحفَظ مباشرة — نفس طريقة "تنزيل الصورة" في التطبيق.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.of(ctx).pop('movements'), child: const Text('سجل الحركة')),
          TextButton(onPressed: () => Navigator.of(ctx).pop('items'), child: const Text('كتالوج الأصناف')),
        ],
      ),
    );
    if (type != null && context.mounted) await _exportCsv(context, type);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('المخزون والقطع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        actions: [
          IconButton(
            tooltip: 'تصدير CSV',
            icon: const Icon(Icons.download_outlined),
            onPressed: () => _openExportDialog(context),
          ),
          PopupMenuButton<Widget>(
            tooltip: 'المزيد',
            icon: const Icon(Icons.more_vert),
            onSelected: (screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)),
            itemBuilder: (context) => const [
              PopupMenuItem(value: InventoryMovementsScreen(), child: Text('سجل حركة المخزون')),
              PopupMenuItem(value: InventorySuppliersScreen(), child: Text('الموردون')),
              PopupMenuItem(value: InventoryWorkSitesScreen(), child: Text('مواقع العمل')),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _QuickMovementBar(onTap: () => openQuickMovementSheet(context)),
            const SizedBox(height: 14),
            const Expanded(child: InventorySection()),
          ],
        ),
      ),
    );
  }
}

/// ودجت "حركة مخزون سريعة" بأعلى الشاشة الرئيسية — بحث عن صنف وتسجيل
/// توريد/صرف/تسوية جرد مباشرة بلا فتح نموذج تعديل الصنف الكامل. راجع
/// inventory_quick_movement_sheet.dart لمحتوى الودجت الفعلي (نافذة سفلية).
class _QuickMovementBar extends StatelessWidget {
  const _QuickMovementBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.inventory.withOpacity(0.08),
          border: Border.all(color: AppColors.inventory.withOpacity(0.35)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.inventory.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.bolt_outlined, color: AppColors.inventory, size: 20),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('حركة مخزون سريعة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('توريد أو صرف أو تسوية جرد لصنف مباشرة', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_left, color: AppColors.inventory),
          ],
        ),
      ),
    );
  }
}

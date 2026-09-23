import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/inventory.dart';
import '../../models/maintenance_report.dart';
import '../../services/app_state.dart';
import '../../services/arabic_format.dart';
import '../../services/auth_service.dart';
import '../../services/constants.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// قسم "المخزون والقطع" — تبويب فرعي جديد داخل لوحة الصيانة (راجع
/// maintenance_dashboard_screen.dart)، وأيضًا الشاشة الوحيدة التي يراها
/// مسؤول المخزون والمصمم (isInventoryOnlyRole في auth_service.dart) بلا أي
/// تبويب آخر بالصيانة. يحوي كتالوج أصناف [InventoryItem] وطلبات قطع
/// [PartRequest] — راجع routes/inventory.js وschema.sql لدورة الحالة الكاملة
/// قبل تعديل هذا الملف: الفني يطلب ← (اختياريًا) مصمم يرفع تصميمًا ← مسؤول
/// المخزون يؤكد الصرف (هنا فقط يُخصم الرصيد) ← إرجاع اختياري لو لم تُستخدم.
class InventorySection extends StatefulWidget {
  const InventorySection({super.key});

  @override
  State<InventorySection> createState() => _InventorySectionState();
}

class _InventorySectionState extends State<InventorySection> {
  bool _showRequests = false;
  String _categoryFilter = 'الكل';
  String _search = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<AppState>().reloadInventoryItems();
      context.read<AppState>().reloadPartRequests();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final currentUser = context.watch<AuthService>().currentUser;
    final role = currentUser?.role ?? AppRole.maintenanceTechnician;
    final canManage = canManageInventory(role);
    final canRequestParts = role == AppRole.admin || isMaintenanceRole(role);
    final canDesign = role == AppRole.admin || role == AppRole.maintenanceManager || isDesigner(role);

    final pendingDesignCount = state.partRequests.where((p) => p.status == PartRequestStatus.pendingDesign).length;
    final pendingIssueCount = state.partRequests.where((p) => p.status == PartRequestStatus.pendingIssue).length;
    final lowStockCount = state.inventoryItems.where((i) => i.isLow).length;

    final categories = ['الكل', ...state.previousInventoryCategories];
    final catalog = state.inventoryItems.where((i) {
      if (_categoryFilter != 'الكل' && (i.category ?? '') != _categoryFilter) return false;
      if (_search.trim().isEmpty) return true;
      return i.name.toLowerCase().contains(_search.trim().toLowerCase());
    }).toList();

    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                KpiCard(value: ArabicFormat.number(state.inventoryItems.length), label: 'أصناف بالكتالوج', valueColor: AppColors.maintenance),
                const SizedBox(width: 10),
                KpiCard(value: ArabicFormat.number(pendingIssueCount + pendingDesignCount), label: 'طلبات مفتوحة', valueColor: AppColors.maintenance),
                const SizedBox(width: 10),
                KpiCard(
                  value: ArabicFormat.number(lowStockCount),
                  label: 'أصناف منخفضة',
                  valueColor: lowStockCount > 0 ? const Color(0xFFB3261E) : AppColors.maintenance,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  Expanded(child: _InnerSegment(label: 'الأصناف', selected: !_showRequests, onTap: () => setState(() => _showRequests = false))),
                  Expanded(
                    child: _InnerSegment(
                      label: 'طلبات القطع',
                      badge: pendingDesignCount + pendingIssueCount,
                      selected: _showRequests,
                      onTap: () => setState(() => _showRequests = true),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (state.inventoryItemsError != null && !_showRequests)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InfoNote(text: state.inventoryItemsError!, color: const Color(0xFFB3261E), icon: Icons.error_outline),
              ),
            if (state.partRequestsError != null && _showRequests)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InfoNote(text: state.partRequestsError!, color: const Color(0xFFB3261E), icon: Icons.error_outline),
              ),
            if (!_showRequests) ...[
              TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'ابحث عن صنف...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.border)),
                ),
              ),
              if (categories.length > 1) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final c = categories[i];
                      final selected = c == _categoryFilter;
                      return ChoiceChip(
                        label: Text(c, style: const TextStyle(fontSize: 12)),
                        selected: selected,
                        selectedColor: AppColors.maintenance.withOpacity(0.16),
                        labelStyle: TextStyle(color: selected ? AppColors.maintenance : AppColors.textSecondary, fontWeight: FontWeight.w600),
                        onSelected: (_) => setState(() => _categoryFilter = c),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 10),
            ],
            Expanded(
              child: _showRequests
                  ? _buildRequestsList(context, state, canManage: canManage, canDesign: canDesign, currentUserId: currentUser?.uid)
                  : _buildCatalogList(context, catalog, canManage: canManage, canRequestParts: canRequestParts),
            ),
            const SizedBox(height: 64),
          ],
        ),
        Positioned(
          bottom: 4,
          left: 4,
          child: !_showRequests
              ? (canManage
                  ? FloatingActionButton.extended(
                      heroTag: 'inv_add_item',
                      backgroundColor: AppColors.maintenance,
                      onPressed: () => _openItemForm(context),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('صنف جديد', style: TextStyle(color: Colors.white)),
                    )
                  : const SizedBox.shrink())
              : (canRequestParts
                  ? FloatingActionButton.extended(
                      heroTag: 'inv_add_request',
                      backgroundColor: AppColors.maintenance,
                      onPressed: () => _openRequestForm(context),
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const Text('طلب قطعة', style: TextStyle(color: Colors.white)),
                    )
                  : const SizedBox.shrink()),
        ),
      ],
    );
  }

  Widget _buildCatalogList(BuildContext context, List<InventoryItem> items, {required bool canManage, required bool canRequestParts}) {
    final state = context.read<AppState>();
    if (!state.inventoryItemsLoaded && state.inventoryItemsError == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (items.isEmpty) {
      return Center(
        child: Text(
          canManage ? 'لا توجد أصناف بعد — اضغط "صنف جديد" للإضافة' : 'لا توجد أصناف مطابقة',
          style: const TextStyle(color: AppColors.textMuted),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => state.reloadInventoryItems(),
      child: ListView.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final item = items[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: item.isLow ? const Color(0xFFB3261E).withOpacity(0.4) : AppColors.border),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(item.name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold))),
                          if (item.isLow) const StatusPill(label: 'منخفض', color: Color(0xFFB3261E), background: Color(0x14B3261E)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (item.category != null && item.category!.isNotEmpty) item.category!,
                          '${ArabicFormat.number(item.quantity)} ${item.unit}',
                        ].join(' — '),
                        style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                if (canRequestParts)
                  IconButton(
                    tooltip: 'طلب هذه القطعة',
                    icon: const Icon(Icons.add_shopping_cart_outlined, size: 19, color: AppColors.maintenance),
                    onPressed: () => _openRequestForm(context, preselected: item),
                  ),
                if (canManage) ...[
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 19, color: AppColors.textMuted),
                    onPressed: () => _openItemForm(context, existing: item),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 19, color: Color(0xFFB3261E)),
                    onPressed: () => _confirmDeleteItem(context, item),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRequestsList(
    BuildContext context,
    AppState state, {
    required bool canManage,
    required bool canDesign,
    required String? currentUserId,
  }) {
    if (!state.partRequestsLoaded && state.partRequestsError == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.partRequests.isEmpty) {
      return const Center(child: Text('لا توجد طلبات قطع بعد', style: TextStyle(color: AppColors.textMuted)));
    }
    return RefreshIndicator(
      onRefresh: () => state.reloadPartRequests(),
      child: ListView.separated(
        itemCount: state.partRequests.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _PartRequestCard(
          request: state.partRequests[i],
          canManage: canManage,
          canDesign: canDesign,
          // إلغاء الطلب متاح لصاحبه فقط (لو لم يُصرف بعد) أو لمن يدير المخزون
          // — بنفس القيد الملزم فعليًا على السيرفر (راجع DELETE
          // /part-requests/:id في routes/inventory.js). زر يظهر ثم يُرفض
          // بـ٤٠٣ تجربة استخدام سيئة، فنخفيه هنا مسبقًا بدل ذلك.
          canCancel: canManage || (currentUserId != null && state.partRequests[i].requestedByUserId == currentUserId),
          onDesign: () => _openDesignSheet(context, state.partRequests[i]),
          onIssue: () => _confirmIssue(context, state.partRequests[i]),
          onReturn: () => _confirmReturn(context, state.partRequests[i]),
          onCancel: () => _confirmCancelRequest(context, state.partRequests[i]),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // نماذج/حوارات
  // -------------------------------------------------------------------

  Future<void> _openItemForm(BuildContext context, {InventoryItem? existing}) async {
    final appState = context.read<AppState>();
    final categories = appState.previousInventoryCategories;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final categoryCtrl = TextEditingController(text: existing?.category ?? '');
    final unitCtrl = TextEditingController(text: existing?.unit ?? 'قطعة');
    final quantityCtrl = TextEditingController(text: (existing?.quantity ?? 0).toString());
    final minQuantityCtrl = TextEditingController(text: existing?.minQuantity?.toString() ?? '');
    final notesCtrl = TextEditingController(text: existing?.notes ?? '');
    bool submitting = false;
    String? error;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(existing == null ? 'إضافة صنف جديد' : 'تعديل الصنف', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Align(alignment: Alignment.centerRight, child: Text('اسم الصنف', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  const SizedBox(height: 6),
                  TextField(controller: nameCtrl, decoration: _fieldDecoration(hint: 'مثال: سير ناقل ٥ سم'), onChanged: (_) => setSheetState(() {})),
                  const SizedBox(height: 12),
                  const Align(alignment: Alignment.centerRight, child: Text('الفئة (اختياري)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  const SizedBox(height: 6),
                  TextField(controller: categoryCtrl, decoration: _fieldDecoration(hint: 'مثال: قطع كهربائية')),
                  if (categories.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: categories
                          .map((c) => ActionChip(label: Text(c, style: const TextStyle(fontSize: 12)), onPressed: () => setSheetState(() => categoryCtrl.text = c)))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('وحدة القياس', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            TextField(controller: unitCtrl, decoration: _fieldDecoration(hint: 'قطعة / متر / لتر')),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('الكمية الحالية', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            TextField(controller: quantityCtrl, keyboardType: TextInputType.number, decoration: _fieldDecoration(hint: '0')),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text('الحد الأدنى للتنبيه (اختياري)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 6),
                  TextField(controller: minQuantityCtrl, keyboardType: TextInputType.number, decoration: _fieldDecoration(hint: 'مثال: ٥')),
                  const SizedBox(height: 12),
                  const Align(alignment: Alignment.centerRight, child: Text('ملاحظات (اختياري)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  const SizedBox(height: 6),
                  TextField(controller: notesCtrl, minLines: 2, maxLines: 3, decoration: _fieldDecoration()),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    InfoNote(text: error!, color: const Color(0xFFB3261E), icon: Icons.error_outline),
                  ],
                  const SizedBox(height: 18),
                  submitting
                      ? const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(color: AppColors.maintenance)))
                      : PrimaryButton(
                          label: existing == null ? 'إضافة الصنف' : 'حفظ التعديلات',
                          color: AppColors.maintenance,
                          onPressed: nameCtrl.text.trim().isEmpty
                              ? null
                              : () async {
                                  final name = nameCtrl.text.trim();
                                  if (name.isEmpty) return;
                                  setSheetState(() {
                                    submitting = true;
                                    error = null;
                                  });
                                  try {
                                    final qty = int.tryParse(quantityCtrl.text.trim()) ?? 0;
                                    final minQty = minQuantityCtrl.text.trim().isEmpty ? null : int.tryParse(minQuantityCtrl.text.trim());
                                    final category = categoryCtrl.text.trim().isEmpty ? null : categoryCtrl.text.trim();
                                    final unit = unitCtrl.text.trim().isEmpty ? 'قطعة' : unitCtrl.text.trim();
                                    final notes = notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim();
                                    if (existing == null) {
                                      await appState.addInventoryItem(name: name, category: category, unit: unit, quantity: qty, minQuantity: minQty, notes: notes);
                                    } else {
                                      await appState.updateInventoryItem(existing.id, name: name, category: category, unit: unit, quantity: qty, minQuantity: minQty, notes: notes);
                                    }
                                    if (ctx.mounted) Navigator.of(ctx).pop();
                                  } catch (e) {
                                    setSheetState(() {
                                      submitting = false;
                                      error = 'تعذّر الحفظ: $e';
                                    });
                                  }
                                },
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteItem(BuildContext context, InventoryItem item) async {
    final appState = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الصنف؟'),
        content: Text('سيُحذف "${item.name}" نهائيًا من الكتالوج.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('حذف', style: TextStyle(color: Color(0xFFB3261E)))),
        ],
      ),
    );
    if (ok == true) await appState.removeInventoryItem(item.id);
  }

  Future<void> _openRequestForm(BuildContext context, {InventoryItem? preselected}) async {
    final appState = context.read<AppState>();
    final items = appState.inventoryItems;
    final openWorkOrders = appState.maintenanceReports.where((r) => r.status != MaintenanceStatus.completed).toList();

    String? selectedItemId = preselected?.id;
    final customNameCtrl = TextEditingController();
    final quantityCtrl = TextEditingController(text: '1');
    final notesCtrl = TextEditingController();
    String? selectedWorkOrderId;
    bool needsDesign = false;
    bool submitting = false;
    String? error;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('طلب قطعة جديد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Align(alignment: Alignment.centerRight, child: Text('الصنف من الكتالوج', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String?>(
                    value: selectedItemId,
                    decoration: _fieldDecoration(),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('قطعة غير موجودة بالكتالوج (اكتب اسمها أدناه)')),
                      ...items.map((i) => DropdownMenuItem<String?>(value: i.id, child: Text('${i.name} — متوفر: ${i.quantity} ${i.unit}'))),
                    ],
                    onChanged: (v) => setSheetState(() => selectedItemId = v),
                  ),
                  if (selectedItemId == null) ...[
                    const SizedBox(height: 12),
                    const Align(alignment: Alignment.centerRight, child: Text('اسم القطعة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                    const SizedBox(height: 6),
                    TextField(controller: customNameCtrl, decoration: _fieldDecoration(hint: 'اكتب اسم القطعة المطلوبة'), onChanged: (_) => setSheetState(() {})),
                  ],
                  const SizedBox(height: 12),
                  const Align(alignment: Alignment.centerRight, child: Text('الكمية', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  const SizedBox(height: 6),
                  TextField(controller: quantityCtrl, keyboardType: TextInputType.number, decoration: _fieldDecoration()),
                  if (openWorkOrders.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Align(alignment: Alignment.centerRight, child: Text('ربط بأمر عمل مفتوح (اختياري)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String?>(
                      value: selectedWorkOrderId,
                      decoration: _fieldDecoration(),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('بدون ربط')),
                        ...openWorkOrders.map((r) => DropdownMenuItem<String?>(value: r.id, child: Text('${r.equipment} — ${r.description}', overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (v) => setSheetState(() => selectedWorkOrderId = v),
                    ),
                  ],
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    value: needsDesign,
                    onChanged: (v) => setSheetState(() => needsDesign = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('تحتاج القطعة تصميمًا قبل توفيرها', style: TextStyle(fontSize: 13)),
                    subtitle: const Text('تذهب أولًا للمصمم لرفع التصميم قبل صرفها', style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                  ),
                  const Align(alignment: Alignment.centerRight, child: Text('ملاحظات (اختياري)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  const SizedBox(height: 6),
                  TextField(controller: notesCtrl, minLines: 2, maxLines: 3, decoration: _fieldDecoration()),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    InfoNote(text: error!, color: const Color(0xFFB3261E), icon: Icons.error_outline),
                  ],
                  const SizedBox(height: 18),
                  submitting
                      ? const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(color: AppColors.maintenance)))
                      : PrimaryButton(
                          label: 'إرسال الطلب',
                          color: AppColors.maintenance,
                          icon: Icons.send,
                          onPressed: (selectedItemId == null && customNameCtrl.text.trim().isEmpty)
                              ? null
                              : () async {
                                  setSheetState(() {
                                    submitting = true;
                                    error = null;
                                  });
                                  try {
                                    final qty = int.tryParse(quantityCtrl.text.trim()) ?? 1;
                                    await appState.createPartRequest(
                                      itemId: selectedItemId,
                                      itemName: selectedItemId == null ? customNameCtrl.text.trim() : null,
                                      quantity: qty < 1 ? 1 : qty,
                                      workOrderId: selectedWorkOrderId,
                                      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                                      needsDesign: needsDesign,
                                    );
                                    if (ctx.mounted) Navigator.of(ctx).pop();
                                  } catch (e) {
                                    setSheetState(() {
                                      submitting = false;
                                      error = 'تعذّر إرسال الطلب: $e';
                                    });
                                  }
                                },
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openDesignSheet(BuildContext context, PartRequest request) async {
    final appState = context.read<AppState>();
    Uint8List? photoBytes;
    String? photoDataUrl;
    final notesCtrl = TextEditingController();
    bool submitting = false;
    String? error;

    Future<void> pickPhoto(BuildContext ctx, void Function(void Function()) setSheetState, ImageSource source) async {
      try {
        final picked = await ImagePicker().pickImage(source: source, maxWidth: 2000, imageQuality: 90);
        if (picked == null) return;
        final bytes = await picked.readAsBytes();
        final name = picked.name.toLowerCase();
        final ext = name.endsWith('.png') ? 'png' : (name.endsWith('.webp') ? 'webp' : 'jpeg');
        setSheetState(() {
          photoBytes = bytes;
          photoDataUrl = 'data:image/$ext;base64,${base64Encode(bytes)}';
        });
      } catch (e) {
        setSheetState(() => error = 'تعذّر اختيار الملف: $e');
      }
    }

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('رفع تصميم — ${request.itemName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () => showModalBottomSheet(
                      context: ctx,
                      builder: (sheetCtx) => SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ListTile(
                              leading: const Icon(Icons.photo_camera_outlined),
                              title: const Text('التقاط صورة بالكاميرا'),
                              onTap: () {
                                Navigator.of(sheetCtx).pop();
                                pickPhoto(ctx, setSheetState, ImageSource.camera);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.photo_library_outlined),
                              title: const Text('اختيار من المعرض'),
                              onTap: () {
                                Navigator.of(sheetCtx).pop();
                                pickPhoto(ctx, setSheetState, ImageSource.gallery);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 140,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: photoBytes == null
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.add_a_photo_outlined, size: 26, color: AppColors.textMuted),
                                  SizedBox(height: 6),
                                  Text('إرفاق ملف/صورة التصميم', style: TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
                                ],
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.memory(photoBytes!, fit: BoxFit.cover, width: double.infinity),
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Align(alignment: Alignment.centerRight, child: Text('ملاحظات التصميم (اختياري)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  const SizedBox(height: 6),
                  TextField(controller: notesCtrl, minLines: 2, maxLines: 3, decoration: _fieldDecoration()),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    InfoNote(text: error!, color: const Color(0xFFB3261E), icon: Icons.error_outline),
                  ],
                  const SizedBox(height: 18),
                  submitting
                      ? const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(color: AppColors.maintenance)))
                      : PrimaryButton(
                          label: 'رفع التصميم وإنهاء المهمة',
                          color: AppColors.maintenance,
                          icon: Icons.upload_outlined,
                          onPressed: photoDataUrl == null
                              ? null
                              : () async {
                                  setSheetState(() {
                                    submitting = true;
                                    error = null;
                                  });
                                  try {
                                    await appState.submitPartDesign(
                                      request.id,
                                      designFileDataUrl: photoDataUrl!,
                                      designNotes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                                    );
                                    if (ctx.mounted) Navigator.of(ctx).pop();
                                  } catch (e) {
                                    setSheetState(() {
                                      submitting = false;
                                      error = 'تعذّر رفع التصميم: $e';
                                    });
                                  }
                                },
                        ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmIssue(BuildContext context, PartRequest request) async {
    final appState = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تأكيد صرف القطعة؟'),
        content: Text('سيُخصم "${request.itemName}" (الكمية: ${request.quantity}) من رصيد المخزون فورًا.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('تأكيد الصرف')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await appState.issuePartRequest(request.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر تأكيد الصرف: $e')));
      }
    }
  }

  Future<void> _confirmReturn(BuildContext context, PartRequest request) async {
    final appState = context.read<AppState>();
    final notesCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إرجاع القطعة للمخزون؟'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('سيُعاد "${request.itemName}" (الكمية: ${request.quantity}) لرصيد المخزون — أُنجزت المهمة بدون استخدامها.'),
            const SizedBox(height: 10),
            TextField(controller: notesCtrl, decoration: const InputDecoration(hintText: 'سبب الإرجاع (اختياري)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('تأكيد الإرجاع')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await appState.returnPartRequest(request.id, returnNotes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim());
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر إرجاع القطعة: $e')));
      }
    }
  }

  Future<void> _confirmCancelRequest(BuildContext context, PartRequest request) async {
    final appState = context.read<AppState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إلغاء الطلب؟'),
        content: Text('سيُلغى طلب "${request.itemName}" نهائيًا.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('تراجع')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('إلغاء الطلب', style: TextStyle(color: Color(0xFFB3261E)))),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await appState.cancelPartRequest(request.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذّر إلغاء الطلب: $e')));
      }
    }
  }
}

InputDecoration _fieldDecoration({String? hint}) {
  return InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(13), borderSide: const BorderSide(color: AppColors.border)),
  );
}

class _InnerSegment extends StatelessWidget {
  final String label;
  final bool selected;
  final int badge;
  final VoidCallback onTap;

  const _InnerSegment({required this.label, required this.selected, required this.onTap, this.badge = 0});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          boxShadow: selected ? [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 3)] : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.bold : FontWeight.w600,
                color: selected ? AppColors.maintenance : AppColors.textMuted,
              ),
            ),
            if (badge > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: const Color(0xFFB3261E), borderRadius: BorderRadius.circular(999)),
                child: Text(ArabicFormat.number(badge), style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PartRequestCard extends StatelessWidget {
  final PartRequest request;
  final bool canManage;
  final bool canDesign;
  final bool canCancel;
  final VoidCallback onDesign;
  final VoidCallback onIssue;
  final VoidCallback onReturn;
  final VoidCallback onCancel;

  const _PartRequestCard({
    required this.request,
    required this.canManage,
    required this.canDesign,
    required this.canCancel,
    required this.onDesign,
    required this.onIssue,
    required this.onReturn,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final statusInfo = switch (request.status) {
      PartRequestStatus.pendingDesign => (label: 'بانتظار التصميم', color: AppColors.warningText, bg: AppColors.warningBg),
      PartRequestStatus.pendingIssue => (label: 'بانتظار الصرف', color: AppColors.maintenance, bg: AppColors.maintenance.withOpacity(0.1)),
      PartRequestStatus.issued => (label: 'تم الصرف', color: AppColors.successText, bg: AppColors.successBg),
      PartRequestStatus.returned => (label: 'مرتجع', color: AppColors.textMuted, bg: AppColors.divider),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('${request.itemName} × ${ArabicFormat.number(request.quantity)}', style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
              ),
              StatusPill(label: statusInfo.label, color: statusInfo.color, background: statusInfo.bg),
            ],
          ),
          const SizedBox(height: 6),
          Text('الطالب: ${request.requestedBy}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          if (request.workOrderDescription != null) Text('مرتبط بـ: ${request.workOrderDescription}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
          if (request.notes != null && request.notes!.isNotEmpty) Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(request.notes!, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
          ),
          if (request.designFileUrl != null) ...[
            const SizedBox(height: 8),
            PhotoThumbnailButton(url: '$kApiOrigin${request.designFileUrl}', height: 110),
          ],
          if (request.status == PartRequestStatus.pendingDesign && canDesign || request.status == PartRequestStatus.pendingIssue && canManage) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (request.status == PartRequestStatus.pendingDesign && canDesign)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onDesign,
                      icon: const Icon(Icons.brush_outlined, size: 16),
                      label: const Text('رفع التصميم'),
                    ),
                  ),
                if (request.status == PartRequestStatus.pendingIssue && canManage)
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.maintenance, foregroundColor: Colors.white),
                      onPressed: onIssue,
                      icon: const Icon(Icons.outbox_outlined, size: 16),
                      label: const Text('تأكيد الصرف'),
                    ),
                  ),
              ],
            ),
          ],
          if (request.status == PartRequestStatus.issued && canManage) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(onPressed: onReturn, icon: const Icon(Icons.undo, size: 16), label: const Text('إرجاع للمخزون')),
          ],
          if (canCancel && (request.status == PartRequestStatus.pendingDesign || request.status == PartRequestStatus.pendingIssue)) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(onPressed: onCancel, child: const Text('إلغاء الطلب', style: TextStyle(color: Color(0xFFB3261E), fontSize: 12))),
            ),
          ],
        ],
      ),
    );
  }
}

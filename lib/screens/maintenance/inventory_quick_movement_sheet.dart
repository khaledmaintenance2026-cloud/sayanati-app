import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/inventory.dart';
import '../../services/app_state.dart';
import '../../services/arabic_format.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// "حركة مخزون سريعة" — ودجت أعلى الشاشة الرئيسية لتبويب المخزون (راجع
/// inventory_dashboard_screen.dart لموضع الزر الذي يفتحها): بحث/اختيار صنف
/// من الكتالوج + تسجيل حركة مباشرة عليه (توريد/صرف استهلاكي/تسوية جرد) بلا
/// فتح نموذج تعديل الصنف الكامل. راجع POST /inventory/items/:id/movement في
/// routes/inventory.js (وappState.recordQuickMovement) لمنطق الحساب الدقيق.
///
/// "تسوية جرد" هنا عملية منفصلة تمامًا عن "تعديل مخزون" في نموذج تعديل
/// الصنف الكامل (inventory_screen.dart، PATCH /items/:id) — قرار صريح من
/// الإدارة أن يبقيا منفصلين، رغم أن أثرهما الحسابي على الرصيد قد يتشابه.
enum _QuickMovementMode { supply, consumableIssue, stockReconciliation }

extension on _QuickMovementMode {
  String get apiType {
    switch (this) {
      case _QuickMovementMode.supply:
        return 'supply';
      case _QuickMovementMode.consumableIssue:
        return 'consumable_issue';
      case _QuickMovementMode.stockReconciliation:
        return 'stock_reconciliation';
    }
  }

  String get label {
    switch (this) {
      case _QuickMovementMode.supply:
        return 'توريد';
      case _QuickMovementMode.consumableIssue:
        return 'صرف';
      case _QuickMovementMode.stockReconciliation:
        return 'تسوية جرد';
    }
  }

  String get quantityFieldLabel {
    switch (this) {
      case _QuickMovementMode.supply:
        return 'الكمية المضافة للمخزون';
      case _QuickMovementMode.consumableIssue:
        return 'الكمية المصروفة من المخزون';
      case _QuickMovementMode.stockReconciliation:
        return 'الرصيد الفعلي بعد الجرد';
    }
  }
}

Future<void> openQuickMovementSheet(BuildContext context, {InventoryItem? preselected}) async {
  final appState = context.read<AppState>();

  String? selectedItemId = preselected?.id;
  _QuickMovementMode mode = _QuickMovementMode.supply;
  final quantityCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  bool submitting = false;
  String? error;

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        final items = context.watch<AppState>().inventoryItems;
        InventoryItem? selectedItem;
        for (final i in items) {
          if (i.id == selectedItemId) {
            selectedItem = i;
            break;
          }
        }

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('حركة مخزون سريعة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Align(alignment: Alignment.centerRight, child: Text('الصنف', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String?>(
                    value: selectedItemId,
                    decoration: fieldDecoration(hint: 'اختر صنفًا من الكتالوج'),
                    isExpanded: true,
                    items: items
                        .map((i) => DropdownMenuItem<String?>(value: i.id, child: Text('${i.name} — متوفر: ${ArabicFormat.number(i.quantity)} ${i.unit}', overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setSheetState(() => selectedItemId = v),
                  ),
                  const SizedBox(height: 14),
                  const Align(alignment: Alignment.centerRight, child: Text('نوع الحركة', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final m in _QuickMovementMode.values)
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(left: m == _QuickMovementMode.values.last ? 0 : 8),
                            child: _ModeButton(label: m.label, selected: mode == m, onTap: () => setSheetState(() => mode = m)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Align(alignment: Alignment.centerRight, child: Text(mode.quantityFieldLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  const SizedBox(height: 6),
                  TextField(
                    controller: quantityCtrl,
                    keyboardType: TextInputType.number,
                    decoration: fieldDecoration(hint: '0'),
                    onChanged: (_) => setSheetState(() {}),
                  ),
                  if (selectedItem != null && mode == _QuickMovementMode.stockReconciliation) ...[
                    const SizedBox(height: 6),
                    Text('الرصيد المسجَّل حاليًا: ${ArabicFormat.number(selectedItem.quantity)} ${selectedItem.unit}', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                  ],
                  const SizedBox(height: 12),
                  const Align(alignment: Alignment.centerRight, child: Text('ملاحظات (اختياري)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                  const SizedBox(height: 6),
                  TextField(controller: notesCtrl, minLines: 2, maxLines: 3, decoration: fieldDecoration()),
                  if (error != null) ...[
                    const SizedBox(height: 10),
                    InfoNote(text: error!, color: const Color(0xFFB3261E), icon: Icons.error_outline),
                  ],
                  const SizedBox(height: 18),
                  submitting
                      ? const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(color: AppColors.inventory)))
                      : PrimaryButton(
                          label: 'تسجيل الحركة',
                          color: AppColors.inventory,
                          icon: Icons.bolt_outlined,
                          onPressed: (selectedItemId == null || quantityCtrl.text.trim().isEmpty)
                              ? null
                              : () async {
                                  final qty = num.tryParse(quantityCtrl.text.trim());
                                  if (qty == null || qty < 0) {
                                    setSheetState(() => error = 'أدخلوا كمية صحيحة');
                                    return;
                                  }
                                  setSheetState(() {
                                    submitting = true;
                                    error = null;
                                  });
                                  try {
                                    await appState.recordQuickMovement(
                                      itemId: selectedItemId!,
                                      type: mode.apiType,
                                      quantity: qty,
                                      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                                    );
                                    if (ctx.mounted) Navigator.of(ctx).pop();
                                  } catch (e) {
                                    setSheetState(() {
                                      submitting = false;
                                      error = 'تعذّر تسجيل الحركة: $e';
                                    });
                                  }
                                },
                        ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.inventory.withOpacity(0.12) : AppColors.surface,
          border: Border.all(color: selected ? AppColors.inventory : AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? AppColors.inventory : AppColors.textSecondary)),
      ),
    );
  }
}

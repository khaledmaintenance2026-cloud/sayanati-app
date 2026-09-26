import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/inventory.dart';
import '../../services/app_state.dart';
import '../../services/arabic_format.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// شاشة سجل حركات المخزون — سجل تدقيق دائم للمراجعة فقط (بلا أي تعديل من
/// هنا)، يعرض كل حركة أثّرت فعليًا على رصيد صنف أو حالة عهدة: ستة أنواع
/// (توريد، صرف استهلاكي، صرف معدات، إعادة معدات، تسوية جرد، تعديل مخزون) —
/// حركات العهدة (صرف/إعادة معدات) موحّدة هنا بنفس السجل بدل أن تبقى منفصلة
/// في شاشة العهدة فقط. راجع services/inventoryMovements.js (logMovement)
/// وroutes/inventory.js وroutes/custody.js لشرح متى تُنشأ كل حركة على وجه
/// الدقة، وschema.sql (جدول inventory_movements) لشرح عمود source ولماذا
/// حركات العهدة بلا كمية رقمية.
class InventoryMovementsScreen extends StatefulWidget {
  const InventoryMovementsScreen({super.key});

  @override
  State<InventoryMovementsScreen> createState() => _InventoryMovementsScreenState();
}

class _InventoryMovementsScreenState extends State<InventoryMovementsScreen> {
  InventoryMovementType? _selectedType; // null = "الكل"

  @override
  void initState() {
    super.initState();
    Future.microtask(() => context.read<AppState>().loadInventoryMovements());
  }

  ({String label, Color color}) _typeInfo(InventoryMovementType type) {
    switch (type) {
      case InventoryMovementType.supply:
        return (label: 'توريد', color: AppColors.successText);
      case InventoryMovementType.consumableIssue:
        return (label: 'صرف استهلاكي', color: const Color(0xFFB3261E));
      case InventoryMovementType.custodyIssue:
        return (label: 'صرف معدات', color: const Color(0xFFE8871E));
      case InventoryMovementType.custodyReturn:
        return (label: 'إعادة معدات', color: const Color(0xFF1E88A8));
      case InventoryMovementType.stockReconciliation:
        return (label: 'تسوية جرد', color: const Color(0xFF5C6BC0));
      case InventoryMovementType.stockAdjustment:
        return (label: 'تعديل مخزون', color: AppColors.inventory);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    Widget body;
    if (!state.inventoryMovementsLoaded && state.inventoryMovementsError == null) {
      body = const Center(child: CircularProgressIndicator());
    } else if (state.inventoryMovementsError != null) {
      body = Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: InfoNote(text: state.inventoryMovementsError!, color: const Color(0xFFB3261E), icon: Icons.error_outline),
        ),
      );
    } else {
      final movements = _selectedType == null
          ? state.inventoryMovements
          : state.inventoryMovements.where((m) => m.type == _selectedType).toList();

      Widget list;
      if (movements.isEmpty) {
        list = const Center(child: Text('لا توجد حركات مسجّلة بهذا النوع', style: TextStyle(color: AppColors.textMuted)));
      } else {
        list = RefreshIndicator(
          onRefresh: () => state.loadInventoryMovements(),
          child: ListView.separated(
            itemCount: movements.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final m = movements[i];
              final info = _typeInfo(m.type);
              final hasQuantity = m.quantityDelta != null && m.quantityAfter != null;
              final deltaText = hasQuantity
                  ? (m.quantityDelta! > 0 ? '+${ArabicFormat.number(m.quantityDelta!)}' : ArabicFormat.number(m.quantityDelta!))
                  : null;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border), borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(m.itemName, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold))),
                        StatusPill(label: info.label, color: info.color, background: info.color.withOpacity(0.1)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    if (hasQuantity)
                      Text(
                        '$deltaText — الرصيد بعدها: ${ArabicFormat.number(m.quantityAfter!)}',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: info.color),
                      )
                    else
                      Text(
                        m.source == InventoryMovementSource.custody ? 'حركة عهدة — بلا رصيد رقمي' : '—',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: info.color),
                      ),
                    const SizedBox(height: 4),
                    Text('بواسطة: ${m.performedBy} — ${ArabicFormat.dateTime(m.createdAt)}', style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                    if (m.notes != null && m.notes!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(m.notes!, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      }

      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _TypeChip(label: 'الكل', selected: _selectedType == null, color: AppColors.textSecondary, onTap: () => setState(() => _selectedType = null)),
                for (final t in InventoryMovementType.values)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 8),
                    child: _TypeChip(
                      label: _typeInfo(t).label,
                      selected: _selectedType == t,
                      color: _typeInfo(t).color,
                      onTap: () => setState(() => _selectedType = t),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: list),
        ],
      );
    }

    return Scaffold(
      appBar: const ScreenTopBar(title: 'سجل حركة المخزون'),
      body: Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 16), child: body),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({required this.label, required this.selected, required this.color, required this.onTap});

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.12) : AppColors.surface,
          border: Border.all(color: selected ? color : AppColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: selected ? color : AppColors.textSecondary)),
      ),
    );
  }
}

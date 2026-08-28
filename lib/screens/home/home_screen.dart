import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state.dart';
import '../../theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  final ValueChanged<int>? onSelectTab;

  const HomeScreen({super.key, this.onSelectTab});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final openReports = state.openEmergencyReports.length;
    final activeLines = state.productionLines.where((l) => l.activeToday).length;
    final pendingPermits = state.permits.where((p) => p.status.name == 'pending').length;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.notifications_none, size: 20, color: AppColors.textSecondary),
                ),
                const Spacer(),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('مرحباً بك', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                    Text('خالد', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Align(
              alignment: Alignment.centerRight,
              child: Text('الأقسام', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 12),
            _ModuleCard(
              icon: Icons.build_outlined,
              color: AppColors.maintenance,
              title: 'الصيانة',
              subtitle: '$openReports بلاغات مفتوحة الآن',
              onTap: () => onSelectTab?.call(1),
            ),
            const SizedBox(height: 12),
            _ModuleCard(
              icon: Icons.factory_outlined,
              color: AppColors.production,
              title: 'الإنتاج',
              subtitle: '$activeLines خطوط إنتاج نشطة',
              onTap: () => onSelectTab?.call(2),
            ),
            const SizedBox(height: 12),
            _ModuleCard(
              icon: Icons.shield_outlined,
              color: AppColors.safety,
              iconColor: AppColors.safetyText,
              title: 'السلامة',
              subtitle: pendingPermits > 0 ? '$pendingPermits تصريح بانتظار الموافقة' : 'لا توجد تصاريح معلّقة',
              onTap: () => onSelectTab?.call(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ModuleCard({
    required this.icon,
    required this.color,
    this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(color: color.withOpacity(0.14), borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: iconColor ?? color, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_left, color: AppColors.textFaint),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_state.dart';
import '../../services/auth_service.dart';
import '../../services/chat_state.dart';
import '../../theme/app_theme.dart';
import '../auth/change_password_screen.dart';
import '../chat/chat_list_screen.dart';
import '../chat/chat_widgets.dart' show ChatUnreadBadge;
import '../notifications/notifications_screen.dart';
import 'section_tools.dart';

class HomeScreen extends StatelessWidget {
  final AppRole role;
  final ValueChanged<String>? onSelectModule;

  const HomeScreen({super.key, required this.role, this.onSelectModule});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final auth = context.watch<AuthService>();
    final chatUnread = context.select<ChatState, int>((c) => c.unreadTotal);
    final openReports = state.openEmergencyReports.length;
    final activeLines = state.productionLines.where((l) => l.activeToday).length;
    final pendingPermits = state.permits.where((p) => p.status.name == 'pending').length;
    final lowStockItems = state.inventoryItems.where((i) => i.isLow).length;

    // الأقسام الأربعة فقط في الرئيسية (إنتاج، صيانة، سلامة، إدارة)، وبقية الشاشات
    // (العمل الإضافي، الإجازات، المعمول، المخزون) أدوات داخل الأقسام — راجع section_tools.dart.
    // مسؤول المخزون والمصمم «أفراد صيانة» بنطاق مهامهما (راجع isInventoryOnlyRole).
    final user = auth.currentUser;
    final sections = visibleSections(user);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
                  ),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.lock_outline, size: 19, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                  ),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        const Center(child: Icon(Icons.notifications_outlined, size: 19, color: AppColors.textSecondary)),
                        if (state.unreadNotificationsCount > 0)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(color: const Color(0xFFB3261E), borderRadius: BorderRadius.circular(8)),
                              constraints: const BoxConstraints(minWidth: 16),
                              child: Text(
                                state.unreadNotificationsCount > 9 ? '٩+' : '${state.unreadNotificationsCount}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // الدردشة الداخلية (محادثات خاصة + مجموعات) مع شارة غير المقروء
                if (chatAvailableForRole(role)) ...[
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ChatListScreen()),
                    ),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Center(child: Icon(Icons.chat_bubble_outline, size: 19, color: AppColors.textSecondary)),
                          if (chatUnread > 0)
                            Positioned(
                              top: -2,
                              right: -2,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(color: const Color(0xFFB3261E), borderRadius: BorderRadius.circular(8)),
                                constraints: const BoxConstraints(minWidth: 16),
                                child: Text(
                                  chatUnread > 9 ? '٩+' : '$chatUnread',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 9.5, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => auth.signOut(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.logout, size: 19, color: AppColors.textSecondary),
                  ),
                ),
                // Expanded بدل Spacer: مع ٤ أزرار في الصف قد يضيق المكان على الشاشات
                // الصغيرة، فنمنع تجاوز الاسم الطويل بالقطع بـ"..." بدل الخطأ.
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('مرحباً بك', style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
                      Text(
                        auth.currentUser?.name ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(roleLabel(role), style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            const Align(
              alignment: Alignment.centerRight,
              child: Text('الأقسام', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            ),
            const SizedBox(height: 12),
            // الأقسام الأربعة داخل قائمة قابلة للتمرير (تتسع كلها في الشاشة عادةً).
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (sections.contains(kSectionProduction)) ...[
                    _ModuleCard(
                      icon: Icons.factory_outlined,
                      color: AppColors.production,
                      title: 'الإنتاج',
                      subtitle: '$activeLines خطوط إنتاج نشطة',
                      hint: _toolsHint(user, kSectionProduction, lowStockItems),
                      onTap: () => onSelectModule?.call(kSectionProduction),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (sections.contains(kSectionMaintenance)) ...[
                    _ModuleCard(
                      icon: Icons.build_outlined,
                      color: AppColors.maintenance,
                      title: 'الصيانة',
                      subtitle: '$openReports بلاغات مفتوحة الآن',
                      hint: _toolsHint(user, kSectionMaintenance, lowStockItems),
                      onTap: () => onSelectModule?.call(kSectionMaintenance),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (sections.contains(kSectionSafety)) ...[
                    _ModuleCard(
                      icon: Icons.shield_outlined,
                      color: AppColors.safety,
                      iconColor: AppColors.safetyText,
                      title: 'السلامة',
                      subtitle: pendingPermits > 0 ? '$pendingPermits تصريح بانتظار الموافقة' : 'لا توجد تصاريح معلّقة',
                      hint: _toolsHint(user, kSectionSafety, lowStockItems),
                      onTap: () => onSelectModule?.call(kSectionSafety),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (sections.contains(kSectionAdmin))
                    _ModuleCard(
                      icon: Icons.admin_panel_settings_outlined,
                      color: AppColors.textSecondary,
                      title: 'الإدارة',
                      subtitle: 'الفنيون واعتماد المستخدمين',
                      hint: _toolsHint(user, kSectionAdmin, lowStockItems),
                      onTap: () => onSelectModule?.call(kSectionAdmin),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// سطر صغير تحت عنوان بطاقة القسم يعدّد الأدوات الموجودة بداخله (مثل «المخزون · المعمول · العمل الإضافي»)
/// كي يعرف المستخدم أين يجد كل شيء. لا يظهر لو لا أدوات في القسم.
String? _toolsHint(AppUser? user, String section, int lowStockItems) {
  final tools = toolsForSection(section, user);
  if (tools.isEmpty) return null;
  final labels = <String>[];
  for (final t in tools) {
    var label = toolLabel(t);
    if (t == kToolInventory && lowStockItems > 0) label = '$label ($lowStockItems منخفض)';
    labels.add(label);
  }
  return labels.join(' · ');
}

class _ModuleCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color? iconColor;
  final String title;
  final String subtitle;

  /// سطر ثانوي صغير يعدّد أدوات القسم (اختياري).
  final String? hint;
  final VoidCallback onTap;

  /// عدّاد أحمر يظهر قبل السهم لو أكبر من صفر (مثل رسائل الدردشة غير المقروءة).
  final int badgeCount;

  const _ModuleCard({
    required this.icon,
    required this.color,
    this.iconColor,
    required this.title,
    required this.subtitle,
    this.hint,
    required this.onTap,
    this.badgeCount = 0,
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
                  if (hint != null) ...[
                    const SizedBox(height: 3),
                    Text(hint!, style: const TextStyle(fontSize: 11.5, color: AppColors.textFaint)),
                  ],
                ],
              ),
            ),
            if (badgeCount > 0) ...[
              ChatUnreadBadge(count: badgeCount),
              const SizedBox(width: 8),
            ],
            const Icon(Icons.chevron_left, color: AppColors.textFaint),
          ],
        ),
      ),
    );
  }
}

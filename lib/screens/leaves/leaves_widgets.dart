import 'package:flutter/material.dart';

import '../../models/leaves.dart';
import '../../services/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// لون قسم «إجازات الموظفين» (أزرق مخضرّ داكن) ولون الخطر.
const Color kLeavesColor = Color(0xFF1B6E87);
const Color kLeavesDanger = Color(0xFFB3261E);

/// عدّاد تغيّر بيانات الإجازات: أي شاشة تعدّل شيئًا تستدعي [notifyLeavesChanged]
/// فتعيد الشاشات المفتوحة (الملخص والقائمة) تحميل بياناتها تلقائيًا.
final ValueNotifier<int> leavesChanged = ValueNotifier<int>(0);

void notifyLeavesChanged() {
  leavesChanged.value = leavesChanged.value + 1;
}

/// نص خطأ جاهز للعرض: رسالة السيرفر العربية لو وُجدت، وإلا رسالة عامة.
String leavesErrorText(Object error) {
  if (error is ApiException) return error.message;
  return 'تعذّر تنفيذ الطلب، تأكد من اتصال الإنترنت ثم حاول مرة أخرى';
}

void showLeavesSnack(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(content: Text(message), backgroundColor: error ? kLeavesDanger : null),
  );
}

/// ألوان شارة حالة الموظف/الإجازة (النص، الخلفية).
Color leaveStatusColor(String status) {
  switch (status) {
    case 'on_leave':
    case 'ongoing':
      return AppColors.maintenance;
    case 'upcoming':
      return AppColors.warningText;
    case 'late':
      return kLeavesDanger;
    case 'completed':
      return AppColors.textSecondary;
    default:
      return AppColors.successText;
  }
}

Color leaveStatusBackground(String status) => leaveStatusColor(status).withOpacity(0.16);

/// هل تُلوَّن بطاقة الموظف في القوائم؟ فقط من في إجازة (أزرق) أو إجازته قادمة (كهرماني)
/// أو متأخر عن المباشرة (أحمر)؛ أما «على رأس العمل» فتبقى بلا تلوين ليبرز غيرهم.
bool leaveIsHighlighted(String status) => status == 'on_leave' || status == 'upcoming' || status == 'late';

/// خلفية بطاقة الموظف في القوائم حسب حالته (تلوين خفيف).
Color leaveTileFill(String status) {
  if (!leaveIsHighlighted(status)) return AppColors.surface;
  return Color.alphaBlend(leaveStatusColor(status).withOpacity(0.10), AppColors.surface);
}

/// حدّ بطاقة الموظف في القوائم حسب حالته.
Color leaveTileBorder(String status) {
  if (!leaveIsHighlighted(status)) return AppColors.border;
  return leaveStatusColor(status).withOpacity(0.45);
}

/// لون التنبيه حسب نوعه: أحمر لما يحتاج إجراءً (تأخر/بلا عودة/رقم خاطئ)، وكهرماني لما عداه.
Color leaveAlertColor(String code) {
  switch (code) {
    case 'late':
    case 'no_return':
    case 'fix_number':
    case 'missing_number':
      return kLeavesDanger;
    default:
      return AppColors.warningText;
  }
}

/// شارة حالة (على رأس العمل / في إجازة / إجازة قادمة / متأخر عن المباشرة).
class LeaveStatusPill extends StatelessWidget {
  final String status;
  final String label;

  const LeaveStatusPill({super.key, required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    return StatusPill(label: label, color: leaveStatusColor(status), background: leaveStatusBackground(status));
  }
}

/// عنوان قسم صغير.
class LeavesSectionTitle extends StatelessWidget {
  final String text;
  const LeavesSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          text,
          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}

/// حالة "لا توجد بيانات" بأيقونة ونص.
class LeavesEmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const LeavesEmptyState({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 46, color: AppColors.textFaint),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: AppColors.textMuted, height: 1.6),
          ),
        ],
      ),
    );
  }
}

/// حالة الخطأ مع زر "إعادة المحاولة".
class LeavesErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const LeavesErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 44, color: kLeavesDanger),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.6),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('إعادة المحاولة'),
            style: OutlinedButton.styleFrom(foregroundColor: kLeavesColor, side: const BorderSide(color: kLeavesColor)),
          ),
        ],
      ),
    );
  }
}

/// مربع رقم/معلومة (عنوان صغير + قيمة كبيرة) لصفحة الموظف والملخص.
class LeaveStatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;

  const LeaveStatTile({super.key, required this.label, required this.value, this.valueColor, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: valueColor ?? AppColors.textPrimary),
              ),
              const SizedBox(height: 3),
              Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
            ],
          ),
        ),
      ),
    );
  }
}

/// شبكة مربعات بعمودين متساويي الارتفاع داخل الصفحات القابلة للتمرير.
class LeavesTilesGrid extends StatelessWidget {
  final List<Widget> tiles;
  const LeavesTilesGrid({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      final second = i + 1 < tiles.length ? tiles[i + 1] : const SizedBox.shrink();
      if (i > 0) rows.add(const SizedBox(height: 10));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tiles[i]),
              const SizedBox(width: 10),
              Expanded(child: second),
            ],
          ),
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: rows);
  }
}

/// حقل تاريخ: يعرض التاريخ المختار (أو تلميحًا) ويفتح منتقي التاريخ عند الضغط.
/// [onChanged] يستلم التاريخ الجديد، أو null عند الضغط على زر المسح (لو [clearable]).
class LeaveDateField extends StatelessWidget {
  final String label;
  final String hint;
  final DateTime? value;
  final DateTime firstDate;
  final DateTime lastDate;
  final bool clearable;
  final ValueChanged<DateTime?> onChanged;

  const LeaveDateField({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.firstDate,
    required this.lastDate,
    required this.onChanged,
    this.clearable = false,
  });

  Future<void> _pick(BuildContext context) async {
    DateTime initial = value ?? DateTime.now();
    if (initial.isBefore(firstDate)) initial = firstDate;
    if (initial.isAfter(lastDate)) initial = lastDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (picked != null) onChanged(DateTime(picked.year, picked.month, picked.day));
  }

  @override
  Widget build(BuildContext context) {
    final v = value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () => _pick(context),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_outlined, size: 19, color: kLeavesColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    v == null ? hint : leaveDateLabel(leaveIsoDate(v)),
                    style: TextStyle(
                      fontSize: 14.5,
                      color: v == null ? AppColors.textMuted : AppColors.textPrimary,
                      fontWeight: v == null ? FontWeight.normal : FontWeight.w600,
                    ),
                  ),
                ),
                if (clearable && v != null)
                  InkWell(
                    onTap: () => onChanged(null),
                    child: const Padding(
                      padding: EdgeInsets.all(2),
                      child: Icon(Icons.close, size: 18, color: AppColors.textMuted),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// ورقة سفلية بخلفية الصفحة وحواف مستديرة — غلاف موحّد لنماذج هذا القسم.
class LeavesSheetFrame extends StatelessWidget {
  final Widget child;
  const LeavesSheetFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: const BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(child: child),
      ),
    );
  }
}

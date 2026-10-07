import 'package:flutter/material.dart';

import '../../models/mamoul_monitor.dart';
import '../../services/api_client.dart';
import '../../services/mamoul_monitor_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart' show fieldDecoration;

/// لون تبويب "المعمول" (بني راتنج البخور) ولون الخطر المستعمل للخارج عن النطاق.
const Color kMamoulColor = Color(0xFF7A4B2A);
const Color kMamoulDanger = Color(0xFFB3261E);

/// عدّاد تغيّر بيانات المعمول (تشغيلة/عيّنة/عيب/عطل). أي شاشة تعدّل شيئًا تستدعي
/// [notifyMamoulChanged]، فتعيد الشاشات المفتوحة (قائمة التشغيلات والأعطال،
/// وهي محفوظة الحالة عند التنقل بين التبويبات) تحميل بياناتها تلقائيًا.
final ValueNotifier<int> mamoulChanged = ValueNotifier<int>(0);

void notifyMamoulChanged() {
  mamoulChanged.value = mamoulChanged.value + 1;
}

/// نص خطأ جاهز للعرض: رسالة السيرفر العربية لو وُجدت، وإلا رسالة عامة.
String mamoulErrorText(Object error) {
  if (error is ApiException) return error.message;
  return 'تعذّر تنفيذ الطلب، تأكد من اتصال الإنترنت ثم حاول مرة أخرى';
}

void showMamoulSnack(BuildContext context, String message, {bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(content: Text(message), backgroundColor: error ? kMamoulDanger : null),
  );
}

/// لون مستوى الوزن: ok أخضر، warn كهرماني، bad أحمر، وغير ذلك رمادي.
Color mamoulLevelColor(String? level) {
  switch (level) {
    case 'ok':
      return AppColors.successText;
    case 'warn':
      return AppColors.warningText;
    case 'bad':
      return kMamoulDanger;
    default:
      return AppColors.textMuted;
  }
}

IconData mamoulLevelIcon(String? level) {
  switch (level) {
    case 'ok':
      return Icons.check_circle_outline;
    case 'warn':
      return Icons.warning_amber_rounded;
    case 'bad':
      return Icons.error_outline;
    default:
      return Icons.hourglass_empty;
  }
}

/// شارة مستوى الوزن (ضمن النطاق / قريب من الحد / خارج النطاق).
class MamoulLevelPill extends StatelessWidget {
  final String level;
  final String? label;

  const MamoulLevelPill({super.key, required this.level, this.label});

  @override
  Widget build(BuildContext context) {
    final color = mamoulLevelColor(level);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(mamoulLevelIcon(level), size: 14, color: color),
          const SizedBox(width: 4),
          Text(label ?? mamoulLevelLabel(level), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

/// حاوية بطاقة موحّدة (حدّ خفيف وحواف دائرية)، قابلة للضغط اختياريًا.
class MamoulCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  const MamoulCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(14),
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: borderColor ?? AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return InkWell(borderRadius: BorderRadius.circular(14), onTap: onTap, child: box);
  }
}

class MamoulSectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const MamoulSectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold))),
        if (trailing != null) trailing!,
      ],
    );
  }
}

/// خلية إحصاء صغيرة: عنوان رمادي فوق قيمة ملوّنة.
class MamoulStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const MamoulStat({super.key, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: color ?? AppColors.textPrimary)),
      ],
    );
  }
}

/// أوزان قطع العيّنة كشرائح: الخارجة عن [min]–[max] بالأحمر.
class MamoulWeightChips extends StatelessWidget {
  final List<double> weights;
  final double min;
  final double max;
  final VoidCallback? onClear;
  final void Function(int index)? onRemove;

  const MamoulWeightChips({
    super.key,
    required this.weights,
    required this.min,
    required this.max,
    this.onClear,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    const eps = 1e-9;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (var i = 0; i < weights.length; i++)
          _chip(weights[i], i, weights[i] < min - eps || weights[i] > max + eps),
      ],
    );
  }

  Widget _chip(double w, int index, bool out) {
    final color = out ? kMamoulDanger : AppColors.textPrimary;
    final body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: out ? kMamoulDanger.withOpacity(0.10) : AppColors.background,
        border: Border.all(color: out ? kMamoulDanger.withOpacity(0.5) : AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(mamoulWeight(w), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color)),
          if (onRemove != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.close, size: 13, color: color.withOpacity(0.7)),
          ],
        ],
      ),
    );
    if (onRemove == null) return body;
    return InkWell(borderRadius: BorderRadius.circular(10), onTap: () => onRemove!(index), child: body);
  }
}

/// سهم لا ينعكس باتجاه النص (لتبقى أسهم التنقل السابق/التالي واضحة في RTL).
Widget _fixedArrow(IconData icon) =>
    Directionality(textDirection: TextDirection.ltr, child: Icon(icon, color: kMamoulColor));

/// شريط التنقل بين الأيام: السابق على اليمين، التالي على اليسار (اتجاه القراءة
/// العربي)، وضغطة على الوسط تفتح اختيار التاريخ.
class MamoulPeriodBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onTap;

  const MamoulPeriodBar({
    super.key,
    required this.title,
    this.subtitle,
    required this.onPrevious,
    required this.onNext,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          IconButton(tooltip: 'السابق', onPressed: onPrevious, icon: _fixedArrow(Icons.chevron_right)),
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    if (subtitle != null)
                      Text(subtitle!, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
                  ],
                ),
              ),
            ),
          ),
          IconButton(tooltip: 'التالي', onPressed: onNext, icon: _fixedArrow(Icons.chevron_left)),
        ],
      ),
    );
  }
}

/// صف خيارات (شرائح اختيار واحد) بلون التبويب: [options] قائمة قيم،
/// [labelOf] تحوّل القيمة لنصها، و[selected] القيمة الحالية (null = لا شيء).
class MamoulChoiceRow<T> extends StatelessWidget {
  final List<T> options;
  final String Function(T value) labelOf;
  final T? selected;
  final ValueChanged<T> onSelected;

  const MamoulChoiceRow({
    super.key,
    required this.options,
    required this.labelOf,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          ChoiceChip(
            label: Text(labelOf(o), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: o == selected ? kMamoulColor : AppColors.textSecondary)),
            selected: o == selected,
            selectedColor: kMamoulColor.withOpacity(0.14),
            backgroundColor: AppColors.surface,
            side: BorderSide(color: o == selected ? kMamoulColor : AppColors.border),
            showCheckmark: false,
            onSelected: (_) => onSelected(o),
          ),
      ],
    );
  }
}

/// عنوان حقل في النماذج (نص صغير فوق الحقل).
class MamoulFieldLabel extends StatelessWidget {
  final String text;
  final bool required;

  const MamoulFieldLabel(this.text, {super.key, this.required = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(required ? '$text *' : text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

/// يحوّل نصًا مكتوبًا (بأرقام لاتينية أو هندية، وفاصلة ',' أو '٫' أو '.') إلى
/// رقم عشري، أو null لو فارغ/غير صالح.
double? mamoulParseNumber(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  const eastern = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = eastern.indexOf(ch);
    if (i >= 0) {
      b.write(i);
    } else if (ch == '٫' || ch == ',' || ch == '،') {
      b.write('.');
    } else {
      b.write(ch);
    }
  }
  s = b.toString();
  return double.tryParse(s);
}

// ---------------------------------------------------------------------------
// المكائن المشتركة بين كل شاشات المعمول
// ---------------------------------------------------------------------------

/// قائمة مكائن المعمول الحالية (تُحمَّل عند فتح التبويب وبعد أي إضافة/تعديل).
final ValueNotifier<List<MamoulMachine>> mamoulMachines = ValueNotifier<List<MamoulMachine>>(const []);

/// true بعد أول تحميل ناجح للمكائن (للتفريق بين "لم تُحمَّل بعد" و"لا توجد مكائن").
final ValueNotifier<bool> mamoulMachinesLoaded = ValueNotifier<bool>(false);

/// يحمّل المكائن من السيرفر. يعيد null عند النجاح، أو نص الخطأ عند الفشل.
Future<String?> reloadMamoulMachines() async {
  try {
    final list = await MamoulMonitorService.fetchMachines();
    mamoulMachines.value = list;
    mamoulMachinesLoaded.value = true;
    return null;
  } catch (e) {
    return mamoulErrorText(e);
  }
}

/// المكينة بمعرّفها من القائمة المحمّلة، أو null.
MamoulMachine? mamoulMachineById(String? id) {
  if (id == null) return null;
  for (final m in mamoulMachines.value) {
    if (m.id == id) return m;
  }
  return null;
}

/// المكائن المفعّلة فقط (هي التي تظهر عند إنشاء تشغيلة/عطل جديد).
List<MamoulMachine> mamoulActiveMachines() => mamoulMachines.value.where((m) => m.active).toList();

/// شرائح اختيار مكينة: [selectedId] = null تعني "كل المكائن" (لو [allowAll]).
class MamoulMachineChips extends StatelessWidget {
  final List<MamoulMachine> machines;
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final bool allowAll;

  const MamoulMachineChips({
    super.key,
    required this.machines,
    required this.selectedId,
    required this.onChanged,
    this.allowAll = true,
  });

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: selected ? kMamoulColor : AppColors.textSecondary)),
      selected: selected,
      selectedColor: kMamoulColor.withOpacity(0.14),
      backgroundColor: AppColors.surface,
      side: BorderSide(color: selected ? kMamoulColor : AppColors.border),
      showCheckmark: false,
      onSelected: (_) => onTap(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (allowAll) _chip('كل المكائن', selectedId == null, () => onChanged(null)),
        for (final m in machines)
          _chip(m.active ? m.name : '${m.name} (معطّلة)', selectedId == m.id, () => onChanged(m.id)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// حالات العرض الشائعة
// ---------------------------------------------------------------------------

class MamoulEmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const MamoulEmptyState({super.key, required this.icon, required this.text});

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

class MamoulErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const MamoulErrorView({super.key, required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        children: [
          const Icon(Icons.error_outline, size: 44, color: kMamoulDanger),
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
            style: OutlinedButton.styleFrom(foregroundColor: kMamoulColor, side: const BorderSide(color: kMamoulColor)),
          ),
        ],
      ),
    );
  }
}

class MamoulLoadingView extends StatelessWidget {
  const MamoulLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: CircularProgressIndicator(color: kMamoulColor)),
    );
  }
}

// ---------------------------------------------------------------------------
// حقول وأدوات نماذج مشتركة
// ---------------------------------------------------------------------------

/// الوقت الحالي بصيغة ٢٤ ساعة 'HH:MM' (التي يطلبها السيرفر).
String mamoulTimeOf(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String mamoulNowTime() => mamoulTimeOf(TimeOfDay.now());

/// 'HH:MM' → TimeOfDay أو null.
TimeOfDay? mamoulParseTime(String? hhmm) {
  if (hhmm == null) return null;
  final parts = hhmm.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
  return TimeOfDay(hour: h, minute: m);
}

/// حقل رقمي (عشري) بإطار التطبيق الموحّد.
class MamoulNumberField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool decimal;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;

  const MamoulNumberField({
    super.key,
    required this.controller,
    required this.hint,
    this.decimal = true,
    this.onSubmitted,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      decoration: fieldDecoration(hint: hint),
    );
  }
}

/// حقل نصي بإطار التطبيق الموحّد.
class MamoulTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final int? maxLength;

  const MamoulTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: fieldDecoration(hint: hint).copyWith(counterText: ''),
    );
  }
}

/// حقل يبدو كحقل نص لكنه يفتح منتقيًا عند الضغط (تاريخ/وقت).
class MamoulPickerField extends StatelessWidget {
  final String text;
  final String hint;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const MamoulPickerField({
    super.key,
    required this.text,
    required this.hint,
    required this.icon,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final empty = text.isEmpty;
    return InkWell(
      borderRadius: BorderRadius.circular(13),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                empty ? hint : text,
                style: TextStyle(fontSize: 14, color: empty ? AppColors.textFaint : AppColors.textPrimary),
              ),
            ),
            if (!empty && onClear != null)
              InkWell(
                onTap: onClear,
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(Icons.close, size: 17, color: AppColors.textMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// نافذة سفلية قابلة للتمرير تتّسع للوحة المفاتيح.
Future<T?> showMamoulSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: builder(ctx),
        ),
      ),
    ),
  );
}

/// حوار تأكيد (حذف وما شابه). يعيد true لو أكّد المستخدم.
Future<bool> confirmMamoul(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'حذف',
  bool danger = true,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('إلغاء')),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel, style: TextStyle(color: danger ? kMamoulDanger : kMamoulColor)),
        ),
      ],
    ),
  );
  return ok == true;
}

/// زر إجراء ثانوي (إطار بلون التبويب) بعرض كامل.
class MamoulOutlineButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color color;

  const MamoulOutlineButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.color = kMamoulColor,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 19),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// مدة وفترات وسرعات (مساعدات عرض)
// ---------------------------------------------------------------------------

/// دقائق → "٣ س ١٢ د" / "٤٥ د" / "—" (لو صفر أو null).
String mamoulDuration(int? minutes) {
  if (minutes == null || minutes <= 0) return '—';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '${mamoulCount(m)} د';
  if (m == 0) return '${mamoulCount(h)} س';
  return '${mamoulCount(h)} س ${mamoulCount(m)} د';
}

/// "سير ٣٥ · دفع ٢٠ · دوار ١٢ هرتز" (القيم الناقصة تظهر "—").
String mamoulSpeedsLine(double? belt, double? push, double? rotary, String unit) {
  return 'سير ${mamoulNum(belt)} · دفع ${mamoulNum(push)} · دوار ${mamoulNum(rotary)} ${mamoulUnitLabel(unit)}';
}

/// بداية فترة "آخر [days] يومًا" بصيغة YYYY-MM-DD (تنتهي اليوم).
String mamoulFromDays(int days) {
  final now = DateTime.now();
  final d = DateTime(now.year, now.month, now.day - (days - 1));
  return mamoulIsoDate(d);
}

String mamoulToday() => mamoulIsoDate(DateTime.now());

const List<int> kMamoulPeriodDays = [30, 90, 365];

String mamoulPeriodLabel(int days) => days == 365 ? 'آخر سنة' : 'آخر ${mamoulCount(days)} يومًا';

/// شرائح اختيار فترة التحليل (٣٠ / ٩٠ يومًا / سنة).
class MamoulDaysChips extends StatelessWidget {
  final int days;
  final ValueChanged<int> onChanged;

  const MamoulDaysChips({super.key, required this.days, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return MamoulChoiceRow<int>(
      options: kMamoulPeriodDays,
      labelOf: mamoulPeriodLabel,
      selected: days,
      onSelected: onChanged,
    );
  }
}

/// أيقونة لكل نوع قطعة معطّلة.
IconData mamoulComponentIcon(String component) {
  switch (component) {
    case 'piston':
      return Icons.compress;
    case 'sensor':
      return Icons.sensors;
    case 'motor_belt':
    case 'motor_push':
    case 'motor_rotary':
      return Icons.settings;
    default:
      return Icons.build_outlined;
  }
}

import '../services/arabic_format.dart';

/// نماذج "العمل الإضافي" (ساعات العمل الإضافي) — تبويب مخصّص للإداريين فقط
/// (مدير النظام ومسؤول الصيانة). تصل كلها من سيرفر صيانتي عبر مسارات
/// /api/overtime (راجع routes/overtime.js على السيرفر).

String? _cleanText(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// فرد في القائمة الدائمة لمن يعملون عملًا إضافيًا (الاسم + الرقم الوظيفي) —
/// لا يشترط أن يكون له حساب في التطبيق.
class OvertimeEmployee {
  final String id;
  final String name;
  final String? employeeNumber;

  const OvertimeEmployee({required this.id, required this.name, this.employeeNumber});

  factory OvertimeEmployee.fromApi(Map<String, dynamic> d) => OvertimeEmployee(
        id: d['id'].toString(),
        name: (d['name'] as String?) ?? '',
        employeeNumber: _cleanText(d['employee_number']),
      );
}

/// سطر فرد داخل سجل عمل إضافي — الاسم والرقم منسوخان داخل السجل نفسه، فيبقى
/// التقرير القديم سليمًا حتى لو حُذف الفرد من القائمة لاحقًا ([employeeId] يصير
/// فارغًا حينها).
class OvertimeEntry {
  final String? employeeId;
  final String name;
  final String? employeeNumber;

  const OvertimeEntry({this.employeeId, required this.name, this.employeeNumber});

  factory OvertimeEntry.fromApi(Map<String, dynamic> d) => OvertimeEntry(
        employeeId: d['employee_id']?.toString(),
        name: (d['name'] as String?) ?? '',
        employeeNumber: _cleanText(d['employee_number']),
      );
}

/// سجل عمل إضافي واحد (عمل معيّن في يوم معيّن بأفراد معيّنين). كل الحقول عدا
/// التاريخ والعمل اختيارية، والتقرير يعرض فقط ما عُبّئ منها.
class OvertimeRecord {
  final String id;

  /// التاريخ بصيغة YYYY-MM-DD.
  final String workDate;
  final String workDescription;
  final String? reason;

  /// الوقت بصيغة HH:mm (٢٤ ساعة) — يأتيان معًا أو لا يأتيان.
  final String? startTime;
  final String? endTime;

  /// المدة بالساعات (يحسبها السيرفر، مع دعم تجاوز منتصف الليل) أو null لو لم
  /// يُحدَّد وقت.
  final double? hours;
  final String? location;
  final String? lines;
  final String? product;
  final String? batch;
  final int? workersCount;
  final List<OvertimeEntry> entries;
  final String? createdBy;

  const OvertimeRecord({
    required this.id,
    required this.workDate,
    required this.workDescription,
    this.reason,
    this.startTime,
    this.endTime,
    this.hours,
    this.location,
    this.lines,
    this.product,
    this.batch,
    this.workersCount,
    this.entries = const [],
    this.createdBy,
  });

  factory OvertimeRecord.fromApi(Map<String, dynamic> d) {
    final rawEntries = (d['entries'] as List?) ?? const [];
    return OvertimeRecord(
      id: d['id'].toString(),
      workDate: (d['work_date'] as String?) ?? '',
      workDescription: (d['work_description'] as String?) ?? '',
      reason: _cleanText(d['reason']),
      startTime: _cleanText(d['start_time']),
      endTime: _cleanText(d['end_time']),
      hours: (d['hours'] as num?)?.toDouble(),
      location: _cleanText(d['location']),
      lines: _cleanText(d['lines']),
      product: _cleanText(d['product']),
      batch: _cleanText(d['batch']),
      workersCount: (d['workers_count'] as num?)?.round(),
      entries: rawEntries.map((e) => OvertimeEntry.fromApi(e as Map<String, dynamic>)).toList(),
      createdBy: _cleanText(d['created_by']),
    );
  }

  int get employeesCount => entries.length;

  /// عدد العمال للعرض: المُدخَل يدويًا إن وُجد، وإلا عدد الأفراد المسجَّلين.
  int get displayWorkersCount => workersCount ?? entries.length;

  /// ساعات الأفراد = مدة العمل × عدد الأفراد (null لو لا وقت).
  double? get personHours => hours == null ? null : hours! * entries.length;
}

/// ملخص فرد واحد ضمن تقرير (يوم/شهر).
class OvertimePersonSummary {
  final String? employeeId;
  final String name;
  final String? employeeNumber;
  final int recordsCount;
  final int daysCount;
  final double hours;

  const OvertimePersonSummary({
    this.employeeId,
    required this.name,
    this.employeeNumber,
    required this.recordsCount,
    required this.daysCount,
    required this.hours,
  });

  factory OvertimePersonSummary.fromApi(Map<String, dynamic> d) => OvertimePersonSummary(
        employeeId: d['employee_id']?.toString(),
        name: (d['name'] as String?) ?? '',
        employeeNumber: _cleanText(d['employee_number']),
        recordsCount: (d['records_count'] as num?)?.round() ?? 0,
        daysCount: (d['days_count'] as num?)?.round() ?? 0,
        hours: (d['hours'] as num?)?.toDouble() ?? 0,
      );
}

/// إجماليات تقرير (يوم/شهر).
class OvertimeSummary {
  final int recordsCount;
  final int daysCount;
  final int employeesCount;
  final double totalHours;
  final double personHours;
  final int recordsWithoutHours;
  final List<OvertimePersonSummary> employees;

  const OvertimeSummary({
    required this.recordsCount,
    required this.daysCount,
    required this.employeesCount,
    required this.totalHours,
    required this.personHours,
    required this.recordsWithoutHours,
    required this.employees,
  });

  factory OvertimeSummary.fromApi(Map<String, dynamic> d) {
    final raw = (d['employees'] as List?) ?? const [];
    return OvertimeSummary(
      recordsCount: (d['records_count'] as num?)?.round() ?? 0,
      daysCount: (d['days_count'] as num?)?.round() ?? 0,
      employeesCount: (d['employees_count'] as num?)?.round() ?? 0,
      totalHours: (d['total_hours'] as num?)?.toDouble() ?? 0,
      personHours: (d['person_hours'] as num?)?.toDouble() ?? 0,
      recordsWithoutHours: (d['records_without_hours'] as num?)?.round() ?? 0,
      employees: raw.map((e) => OvertimePersonSummary.fromApi(e as Map<String, dynamic>)).toList(),
    );
  }
}

/// تقرير عمل إضافي ليوم ('day') أو شهر ('month') أو مدة ('range').
class OvertimeReport {
  final String mode;
  final String from;
  final String to;
  final List<OvertimeRecord> records;
  final OvertimeSummary summary;

  const OvertimeReport({
    required this.mode,
    required this.from,
    required this.to,
    required this.records,
    required this.summary,
  });

  factory OvertimeReport.fromApi(Map<String, dynamic> d) {
    final raw = (d['records'] as List?) ?? const [];
    return OvertimeReport(
      mode: (d['mode'] as String?) ?? 'day',
      from: (d['from'] as String?) ?? '',
      to: (d['to'] as String?) ?? '',
      records: raw.map((e) => OvertimeRecord.fromApi(e as Map<String, dynamic>)).toList(),
      summary: OvertimeSummary.fromApi((d['summary'] as Map<String, dynamic>?) ?? const <String, dynamic>{}),
    );
  }
}

// ---------------------------------------------------------------------------
// تنسيق التاريخ والساعات (بأرقام هندية، مثل باقي التطبيق)
// ---------------------------------------------------------------------------

const List<String> _weekdayNames = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
const List<String> _monthNames = [
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

/// DateTime → 'YYYY-MM-DD' (للإرسال للسيرفر).
String overtimeIsoDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

/// 'YYYY-MM-DD' → DateTime (منتصف الليل المحلي)، أو null لو غير صالح.
DateTime? overtimeParseDate(String iso) {
  final parts = iso.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// 'YYYY-MM' من DateTime.
String overtimeIsoMonth(DateTime d) => overtimeIsoDate(d).substring(0, 7);

/// اسم يوم الأسبوع بالعربية (الأحد…السبت).
String overtimeWeekdayName(DateTime d) => _weekdayNames[d.weekday % 7];

/// اسم الشهر بالعربية (يناير…ديسمبر) — الرقم من ١ إلى ١٢.
String overtimeMonthName(int month) => _monthNames[(month - 1).clamp(0, 11)];

/// '2026-10-06' → '٢٠٢٦/١٠/٠٦'.
String overtimeDateLabel(String iso) => ArabicFormat.toEasternDigits(iso.replaceAll('-', '/'));

/// '17:30' → '١٧:٣٠'.
String overtimeTimeLabel(String hhmm) => ArabicFormat.toEasternDigits(hhmm);

/// عدد صحيح بأرقام هندية: 12 → '١٢'.
String overtimeCount(int n) => ArabicFormat.toEasternDigits(n);

/// رقم وظيفي بأرقام هندية: '1024' → '١٠٢٤'.
String overtimeNumberLabel(String number) => ArabicFormat.toEasternDigits(number);

/// ٤٫٥ ساعة / ٣ ساعة.
String overtimeHoursLabel(double hours) {
  final isWhole = hours == hours.roundToDouble();
  final text = isWhole ? hours.round().toString() : hours.toString();
  return '${ArabicFormat.toEasternDigits(text).replaceAll('.', '٫')} ساعة';
}

/// مدة بين وقتين HH:mm بالساعات (تجاوز منتصف الليل مدعوم) — نفس منطق السيرفر،
/// للمعاينة الفورية داخل نموذج السجل فقط (القيمة الرسمية يحسبها السيرفر).
double? overtimeHoursBetween(String? start, String? end) {
  if (start == null || end == null) return null;
  final s = start.split(':');
  final e = end.split(':');
  if (s.length != 2 || e.length != 2) return null;
  final sh = int.tryParse(s[0]);
  final sm = int.tryParse(s[1]);
  final eh = int.tryParse(e[0]);
  final em = int.tryParse(e[1]);
  if (sh == null || sm == null || eh == null || em == null) return null;
  var minutes = eh * 60 + em - (sh * 60 + sm);
  if (minutes <= 0) minutes += 1440;
  return (minutes / 60 * 100).round() / 100;
}

import '../services/arabic_format.dart';

// ============================================================================
// نماذج «إجازات الموظفين» (مصنع الرجال) — تطابق ردود السيرفر في routes/leaves.js.
// كل الأرصدة والأيام المدفوعة/بدون راتب تُحسب في السيرفر فقط؛ التطبيق يعرضها ولا يحسبها.
// ============================================================================

// ------------------------------- تنسيق العرض -------------------------------

/// 'YYYY-MM-DD' → '٢٠٢٦/١٠/٢٥' (أو '—' لو فارغ).
String leaveDateLabel(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  return ArabicFormat.toEasternDigits(iso.replaceAll('-', '/'));
}

/// DateTime → 'YYYY-MM-DD'.
String leaveIsoDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

/// 'YYYY-MM-DD' → DateTime (منتصف الليل المحلي)، أو null لو فارغ/غير صالح.
DateTime? leaveParseDate(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  final parts = iso.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

/// رقم صحيح بالأرقام الهندية: ٢١٤٥.
String leaveNum(int n) => ArabicFormat.toEasternDigits(n);

/// نص يحتوي أرقامًا لاتينية (مثل رقم وظيفي) بالأرقام الهندية: '2145' ← '٢١٤٥'.
String leaveEastern(String s) => ArabicFormat.toEasternDigits(s);

/// يحوّل الأرقام الهندية/الفارسية (٠-٩ و۰-۹) في نص إلى لاتينية — لمطابقة البحث بالرقم الوظيفي.
String leaveWesternDigits(String s) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  final buffer = StringBuffer();
  for (final ch in s.split('')) {
    var i = arabic.indexOf(ch);
    if (i < 0) i = persian.indexOf(ch);
    buffer.write(i >= 0 ? i.toString() : ch);
  }
  return buffer.toString();
}

/// عدد الأيام الكاملة بين تاريخين (a − b) بتجاهل الوقت (آمن مع تغيّر التوقيت الصيفي).
int leaveDayDiff(DateTime a, DateTime b) {
  final ua = DateTime.utc(a.year, a.month, a.day);
  final ub = DateTime.utc(b.year, b.month, b.day);
  return ua.difference(ub).inDays;
}

/// عدد أيام بصياغة عربية صحيحة: يوم واحد / يومان / ٣ أيام / ١١ يومًا.
String leaveDays(int n) {
  if (n == 0) return '٠ يوم';
  if (n == 1) return 'يوم واحد';
  if (n == 2) return 'يومان';
  if (n >= 3 && n <= 10) return '${ArabicFormat.toEasternDigits(n)} أيام';
  return '${ArabicFormat.toEasternDigits(n)} يومًا';
}

/// مقدار أيام عشري (رصيد) بمنزلتين كحد أقصى بلا أصفار زائدة: ٩٫٩٥ / ٤٢ / ٠.
String leaveAmount(double v) {
  var s = v.toStringAsFixed(2);
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '');
    if (s.endsWith('.')) s = s.substring(0, s.length - 1);
  }
  return ArabicFormat.toEasternDigits(s).replaceAll('.', '٫');
}

/// رصيد بصياغة «٩٫٩٥ يوم».
String leaveAmountDays(double v) => '${leaveAmount(v)} يوم';

/// مدة الخدمة بالأيام → «٢٥٧ يومًا (نحو ٨ أشهر)».
String leaveServiceText(int days) {
  final base = leaveDays(days);
  if (days < 30) return base;
  final years = days ~/ 365;
  final months = (days % 365) ~/ 30;
  final parts = <String>[];
  if (years > 0) parts.add(years == 1 ? 'سنة' : (years == 2 ? 'سنتان' : '${ArabicFormat.toEasternDigits(years)} سنوات'));
  if (months > 0) parts.add(months == 1 ? 'شهر' : (months == 2 ? 'شهران' : '${ArabicFormat.toEasternDigits(months)} أشهر'));
  if (parts.isEmpty) return base;
  return '$base (نحو ${parts.join(' و')})';
}

// ------------------------------- أدوات قراءة JSON -------------------------------

List<dynamic> _list(dynamic v) => v is List ? v : const [];
String? _str(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

double? _dbl(dynamic v) => v is num ? v.toDouble() : null;
int? _int(dynamic v) => v is num ? v.toInt() : null;

// ------------------------------- الإعدادات -------------------------------

class LeaveSettings {
  final double annualDays;
  final int expiryYears;
  final String paidRounding; // 'nearest' | 'floor'
  final int soonDays;
  final bool alertsEnabled;
  final double capDays;

  const LeaveSettings({
    required this.annualDays,
    required this.expiryYears,
    required this.paidRounding,
    required this.soonDays,
    required this.alertsEnabled,
    required this.capDays,
  });

  factory LeaveSettings.fromApi(Map<String, dynamic> d) => LeaveSettings(
        annualDays: _dbl(d['annual_days']) ?? 21,
        expiryYears: _int(d['expiry_years']) ?? 2,
        paidRounding: (d['paid_rounding'] as String?) ?? 'nearest',
        soonDays: _int(d['soon_days']) ?? 7,
        alertsEnabled: d['alerts_enabled'] != false,
        capDays: _dbl(d['cap_days']) ?? 42,
      );
}

// ------------------------------- التنبيهات والإجازات -------------------------------

class LeaveAlert {
  final String code; // missing_dates | fix_number | missing_number | late | no_return | soon | at_cap
  final String text;
  final String? leaveId;

  const LeaveAlert({required this.code, required this.text, this.leaveId});

  factory LeaveAlert.fromApi(Map<String, dynamic> d) => LeaveAlert(
        code: (d['code'] as String?) ?? '',
        text: (d['text'] as String?) ?? '',
        leaveId: _str(d['leave_id']),
      );
}

/// إجازة واحدة بكل ما يحسبه السيرفر لها.
class LeaveRecord {
  final String id;
  final String start;
  final String? expected;
  final String? actual;
  final String? end;
  final int duration;
  final bool provisional;
  final String state; // completed | ongoing | upcoming | late
  final String stateLabel;
  final int? paid;
  final int? unpaid;
  final double? balanceAtStart;
  final String? note;
  final String? replacement; // الموظف البديل (اختياري)

  const LeaveRecord({
    required this.id,
    required this.start,
    required this.expected,
    required this.actual,
    required this.end,
    required this.duration,
    required this.provisional,
    required this.state,
    required this.stateLabel,
    required this.paid,
    required this.unpaid,
    required this.balanceAtStart,
    required this.note,
    required this.replacement,
  });

  factory LeaveRecord.fromApi(Map<String, dynamic> d) => LeaveRecord(
        id: d['id'].toString(),
        start: (d['start'] as String?) ?? '',
        expected: _str(d['expected']),
        actual: _str(d['actual']),
        end: _str(d['end']),
        duration: _int(d['duration']) ?? 0,
        provisional: d['provisional'] == true,
        state: (d['state'] as String?) ?? 'completed',
        stateLabel: (d['state_label'] as String?) ?? '',
        paid: _int(d['paid']),
        unpaid: _int(d['unpaid']),
        balanceAtStart: _dbl(d['balance_at_start']),
        note: _str(d['note']),
        replacement: _str(d['replacement']),
      );

  /// هل يمكن تسجيل المباشرة لهذه الإجازة؟ (بدأت ولم تُسجَّل مباشرتها بعد)
  bool get canRegisterReturn => actual == null && (state == 'ongoing' || state == 'late');
}

/// الإجازة الأبرز في قائمة الموظفين (متأخرة ثم جارية ثم أقرب قادمة).
class LeaveBrief {
  final String id;
  final String start;
  final String? expected;
  final String? actual;
  final String state;
  final String stateLabel;

  const LeaveBrief({
    required this.id,
    required this.start,
    required this.expected,
    required this.actual,
    required this.state,
    required this.stateLabel,
  });

  factory LeaveBrief.fromApi(Map<String, dynamic> d) => LeaveBrief(
        id: d['id'].toString(),
        start: (d['start'] as String?) ?? '',
        expected: _str(d['expected']),
        actual: _str(d['actual']),
        state: (d['state'] as String?) ?? '',
        stateLabel: (d['state_label'] as String?) ?? '',
      );
}

// ------------------------------- الموظف -------------------------------

class LeaveEmployee {
  final String id;
  final String name;
  final String? employeeNumber;
  final String? department;
  final String? hireDate;
  final String? startDate;
  final String status; // active | on_leave | upcoming | late
  final String statusLabel;
  final bool hasBalance;
  final double? available;
  final bool atCap;
  final int? serviceDays;
  final int? unpaidTotal;
  final List<LeaveAlert> alerts;
  final LeaveBrief? leave;

  // تفاصيل صفحة الموظف فقط (null في القائمة)
  final double? accrued;
  final double? used;
  final double? expired;
  final double? capDays;
  final List<LeaveRecord> leaves;

  const LeaveEmployee({
    required this.id,
    required this.name,
    required this.employeeNumber,
    required this.department,
    required this.hireDate,
    required this.startDate,
    required this.status,
    required this.statusLabel,
    required this.hasBalance,
    required this.available,
    required this.atCap,
    required this.serviceDays,
    required this.unpaidTotal,
    required this.alerts,
    required this.leave,
    required this.accrued,
    required this.used,
    required this.expired,
    required this.capDays,
    required this.leaves,
  });

  factory LeaveEmployee.fromApi(Map<String, dynamic> d) {
    final leaveMap = d['leave'];
    return LeaveEmployee(
      id: d['id'].toString(),
      name: (d['name'] as String?) ?? '',
      employeeNumber: _str(d['employee_number']),
      department: _str(d['department']),
      hireDate: _str(d['hire_date']),
      startDate: _str(d['start_date']),
      status: (d['status'] as String?) ?? 'active',
      statusLabel: (d['status_label'] as String?) ?? '',
      hasBalance: d['has_balance'] == true,
      available: _dbl(d['available']),
      atCap: d['at_cap'] == true,
      serviceDays: _int(d['service_days']),
      unpaidTotal: _int(d['unpaid_total']),
      alerts: _list(d['alerts']).map((e) => LeaveAlert.fromApi(e as Map<String, dynamic>)).toList(),
      leave: leaveMap is Map<String, dynamic> ? LeaveBrief.fromApi(leaveMap) : null,
      accrued: _dbl(d['accrued']),
      used: _dbl(d['used']),
      expired: _dbl(d['expired']),
      capDays: _dbl(d['cap_days']),
      leaves: _list(d['leaves']).map((e) => LeaveRecord.fromApi(e as Map<String, dynamic>)).toList(),
    );
  }

  bool hasAlert(String code) {
    for (final a in alerts) {
      if (a.code == code) return true;
    }
    return false;
  }

  /// أكثر تنبيه أهمية للعرض في القائمة (متأخر ثم بلا عودة ثم الحد الأقصى ثم قادمة ثم نقص بيانات).
  LeaveAlert? get topAlert {
    const order = ['late', 'no_return', 'at_cap', 'soon', 'fix_number', 'missing_number', 'missing_dates'];
    for (final code in order) {
      for (final a in alerts) {
        if (a.code == code) return a;
      }
    }
    return alerts.isEmpty ? null : alerts.first;
  }

  /// «٢١٤٥» أو 'بدون رقم'.
  String get numberLabel => employeeNumber == null ? 'بدون رقم وظيفي' : ArabicFormat.toEasternDigits(employeeNumber!);
}

// ------------------------------- معاينة قبل الحفظ -------------------------------

class LeavePreview {
  final String start;
  final String? expected;
  final String? actual;
  final int duration;
  final bool hasBalance;
  final double? balanceAtStart;
  final int? paid;
  final int? unpaid;
  final String paidRounding;
  final String? message;

  const LeavePreview({
    required this.start,
    required this.expected,
    required this.actual,
    required this.duration,
    required this.hasBalance,
    required this.balanceAtStart,
    required this.paid,
    required this.unpaid,
    required this.paidRounding,
    required this.message,
  });

  factory LeavePreview.fromApi(Map<String, dynamic> d) => LeavePreview(
        start: (d['start'] as String?) ?? '',
        expected: _str(d['expected']),
        actual: _str(d['actual']),
        duration: _int(d['duration']) ?? 0,
        hasBalance: d['has_balance'] == true,
        balanceAtStart: _dbl(d['balance_at_start']),
        paid: _int(d['paid']),
        unpaid: _int(d['unpaid']),
        paidRounding: (d['paid_rounding'] as String?) ?? 'nearest',
        message: _str(d['message']),
      );
}

// ------------------------------- لوحة الملخص -------------------------------

class LeaveSummaryCounts {
  final int employees;
  final int active;
  final int onLeave;
  final int awayNow;
  final int upcomingLeaves;
  final int lateCount;
  final int atCap;
  final int missingDates;
  final int noReturn;
  final int fixNumber;

  const LeaveSummaryCounts({
    required this.employees,
    required this.active,
    required this.onLeave,
    required this.awayNow,
    required this.upcomingLeaves,
    required this.lateCount,
    required this.atCap,
    required this.missingDates,
    required this.noReturn,
    required this.fixNumber,
  });

  factory LeaveSummaryCounts.fromApi(Map<String, dynamic> d) => LeaveSummaryCounts(
        employees: _int(d['employees']) ?? 0,
        active: _int(d['active']) ?? 0,
        onLeave: _int(d['on_leave']) ?? 0,
        awayNow: _int(d['away_now']) ?? 0,
        upcomingLeaves: _int(d['upcoming_leaves']) ?? 0,
        lateCount: _int(d['late']) ?? 0,
        atCap: _int(d['at_cap']) ?? 0,
        missingDates: _int(d['missing_dates']) ?? 0,
        noReturn: _int(d['no_return']) ?? 0,
        fixNumber: _int(d['fix_number']) ?? 0,
      );
}

/// سطر موجز لموظف داخل قوائم الملخص.
class LeaveSummaryItem {
  final String employeeId;
  final String name;
  final String? employeeNumber;
  final String? department;
  final String? start;
  final String? expected;
  final int? daysLeft;
  final double? available;
  final String? note;

  const LeaveSummaryItem({
    required this.employeeId,
    required this.name,
    required this.employeeNumber,
    required this.department,
    required this.start,
    required this.expected,
    required this.daysLeft,
    required this.available,
    required this.note,
  });

  factory LeaveSummaryItem.fromApi(Map<String, dynamic> d) {
    final leaveMap = d['leave'];
    String? start = _str(d['start']);
    String? expected = _str(d['expected']);
    if (leaveMap is Map<String, dynamic>) {
      start = start ?? _str(leaveMap['start']);
      expected = expected ?? _str(leaveMap['expected']);
    }
    String? note;
    final alerts = _list(d['alerts']);
    if (alerts.isNotEmpty && alerts.first is Map<String, dynamic>) {
      note = _str((alerts.first as Map<String, dynamic>)['text']);
    }
    return LeaveSummaryItem(
      employeeId: d['id'].toString(),
      name: (d['name'] as String?) ?? '',
      employeeNumber: _str(d['employee_number']),
      department: _str(d['department']),
      start: start,
      expected: expected,
      daysLeft: _int(d['days_left']),
      available: _dbl(d['available']),
      note: note,
    );
  }
}

class LeaveSummary {
  final String today;
  final LeaveSettings settings;
  final LeaveSummaryCounts counts;
  final List<LeaveSummaryItem> awayNow;
  final List<LeaveSummaryItem> upcoming;
  final List<LeaveSummaryItem> lateEmployees;
  final List<LeaveSummaryItem> atCap;
  final List<LeaveSummaryItem> missingDates;
  final List<LeaveSummaryItem> noReturn;
  final List<LeaveSummaryItem> fixNumber;

  const LeaveSummary({
    required this.today,
    required this.settings,
    required this.counts,
    required this.awayNow,
    required this.upcoming,
    required this.lateEmployees,
    required this.atCap,
    required this.missingDates,
    required this.noReturn,
    required this.fixNumber,
  });

  static List<LeaveSummaryItem> _items(dynamic v) =>
      _list(v).map((e) => LeaveSummaryItem.fromApi(e as Map<String, dynamic>)).toList();

  factory LeaveSummary.fromApi(Map<String, dynamic> d) {
    final lists = (d['lists'] as Map<String, dynamic>?) ?? const <String, dynamic>{};
    return LeaveSummary(
      today: (d['today'] as String?) ?? '',
      settings: LeaveSettings.fromApi((d['settings'] as Map<String, dynamic>?) ?? const <String, dynamic>{}),
      counts: LeaveSummaryCounts.fromApi((d['counts'] as Map<String, dynamic>?) ?? const <String, dynamic>{}),
      awayNow: _items(lists['away_now']),
      upcoming: _items(lists['upcoming']),
      lateEmployees: _items(lists['late']),
      atCap: _items(lists['at_cap']),
      missingDates: _items(lists['missing_dates']),
      noReturn: _items(lists['no_return']),
      fixNumber: _items(lists['fix_number']),
    );
  }
}

// ------------------------------- التقارير -------------------------------

/// تقرير جاهز من السيرفر (شامل أو كشف موظف): صفحة HTML كاملة للطباعة/PDF + بياناته الوصفية.
/// السيرفر هو من يبني الجدول بنفس أعمدة ملف الإكسل، والتطبيق يعرضه فقط.
class LeaveReportData {
  final String kind; // all | person
  final String title;
  final String subtitle;
  final String orientation; // landscape | portrait
  final String filename;
  final int count;
  final String html;

  const LeaveReportData({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.orientation,
    required this.filename,
    required this.count,
    required this.html,
  });

  bool get isLandscape => orientation == 'landscape';

  factory LeaveReportData.fromApi(Map<String, dynamic> d) => LeaveReportData(
        kind: (d['kind'] as String?) ?? 'all',
        title: (d['title'] as String?) ?? 'تقرير الإجازات',
        subtitle: (d['subtitle'] as String?) ?? '',
        orientation: (d['orientation'] as String?) == 'portrait' ? 'portrait' : 'landscape',
        filename: (d['filename'] as String?) ?? 'leaves-report.pdf',
        count: _int(d['count']) ?? 0,
        html: (d['html'] as String?) ?? '',
      );
}

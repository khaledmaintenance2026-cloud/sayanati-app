import 'dart:math' as math;

import '../services/arabic_format.dart';

/// نماذج "مراقبة مكينة المعمول (البخور)" — تبويب لفريق الصيانة وإنتاج مصنع
/// النساء. تصل كلها من سيرفر صيانتي عبر مسارات /api/mamoul-monitor (راجع
/// routes/mamoulMonitor.js على السيرفر). أرقام الوزن بالجرام، والحدّان
/// المقبولان ٦٫٠ إلى ٦٫٤ (ينسخهما السيرفر داخل كل تشغيلة).

double? _dbl(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

int _int(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

String? _txt(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// حدّا الوزن المقبولان وهدفاه الافتراضيان (قرار الإدارة 2026-10-07). تُستخدم
/// قبل وصول بيانات التشغيلة من السيرفر (نموذج تشغيلة جديدة)؛ كل تشغيلة بعد
/// إنشائها تحمل حدودها المنسوخة.
const double kMamoulWeightMin = 6.0;
const double kMamoulWeightMax = 6.4;
const List<double> kMamoulTargets = [6.2, 6.4];

/// هامش التنبيه المبكر (جرام): متوسط يقترب من أحد الحدّين بأقل من هذا الهامش.
const double kMamoulWarnMargin = 0.05;

/// أقل عدد قطع مقاسة لتركيبة سرعات حتى تُقترح "أفضل ضبط" (نفس قيمة السيرفر).
const int kMamoulMinPieces = 20;

const List<String> kMamoulSpeedUnits = ['Hz', '%', 'RPM'];

const Map<String, String> kMamoulUnitLabels = {'Hz': 'هرتز', '%': '٪', 'RPM': 'دورة/د'};

const Map<String, String> kMamoulMoistureLabels = {'dry': 'جافة', 'medium': 'متوسطة', 'wet': 'رطبة'};

const Map<String, String> kMamoulComponentLabels = {
  'piston': 'بستون',
  'sensor': 'حساس',
  'motor_belt': 'محرك السير',
  'motor_push': 'محرك الدفع',
  'motor_rotary': 'محرك الدوار',
  'other': 'أخرى',
};

const List<String> kMamoulShifts = ['صباحي', 'مسائي', 'ليلي'];

String mamoulUnitLabel(String unit) => kMamoulUnitLabels[unit] ?? unit;
String mamoulMoistureLabel(String? level) => level == null ? '—' : (kMamoulMoistureLabels[level] ?? level);
String mamoulComponentLabel(String component) => kMamoulComponentLabels[component] ?? component;

// ---------------------------------------------------------------------------
// تنسيق التاريخ والأرقام (بأرقام هندية، مثل باقي التطبيق)
// ---------------------------------------------------------------------------

const List<String> _weekdayNames = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];

/// DateTime → 'YYYY-MM-DD' (للإرسال للسيرفر).
String mamoulIsoDate(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

/// 'YYYY-MM-DD' → DateTime، أو null لو غير صالح.
DateTime? mamoulParseDate(String iso) {
  final parts = iso.split('-');
  if (parts.length != 3) return null;
  final y = int.tryParse(parts[0]);
  final m = int.tryParse(parts[1]);
  final d = int.tryParse(parts[2]);
  if (y == null || m == null || d == null) return null;
  return DateTime(y, m, d);
}

String mamoulWeekdayName(DateTime d) => _weekdayNames[d.weekday % 7];

/// '2026-10-07' → '٢٠٢٦/١٠/٠٧'.
String mamoulDateLabel(String iso) => ArabicFormat.toEasternDigits(iso.replaceAll('-', '/'));

/// '17:30' → '١٧:٣٠'.
String mamoulTimeLabel(String hhmm) => ArabicFormat.toEasternDigits(hhmm);

String mamoulCount(int n) => ArabicFormat.toEasternDigits(n);

/// رقم بمنازل عشرية حتى [decimals] مع حذف الأصفار الزائدة وفاصلة عربية:
/// 6.2 → '٦٫٢'، 35 → '٣٥'، null → '—'.
String mamoulNum(double? v, {int decimals = 2}) {
  if (v == null) return '—';
  var s = v.toStringAsFixed(decimals);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
  }
  return ArabicFormat.toEasternDigits(s).replaceAll('.', '٫');
}

/// وزن بمنزلتين ثابتتين: 6.2 → '٦٫٢٠' (مطابق لقراءة الميزان).
String mamoulWeight(double? v) {
  if (v == null) return '—';
  return ArabicFormat.toEasternDigits(v.toStringAsFixed(2)).replaceAll('.', '٫');
}

/// نسبة مئوية: 12.5 → '١٢٫٥٪'، null → '—'.
String mamoulPct(double? v) => v == null ? '—' : '${mamoulNum(v, decimals: 1)}٪';

/// سرعة مع وحدتها: (35, 'Hz') → '٣٥ هرتز'.
String mamoulSpeed(double? v, String unit) => v == null ? '—' : '${mamoulNum(v)} ${mamoulUnitLabel(unit)}';

// ---------------------------------------------------------------------------
// إحصاءات الأوزان
// ---------------------------------------------------------------------------

/// إحصاءات مجموعة أوزان (عيّنة أو تشغيلة). level: none | ok | warn | bad.
class WeightStats {
  final int count;
  final double? avg;
  final double? min;
  final double? max;
  final double? std;
  final int lowCount;
  final int highCount;
  final int outCount;
  final double? outPct;
  final double? deviation;

  /// 'high' | 'low' | null — ميل المتوسط نحو أحد الحدّين.
  final String? trend;
  final String level;

  const WeightStats({
    required this.count,
    this.avg,
    this.min,
    this.max,
    this.std,
    this.lowCount = 0,
    this.highCount = 0,
    this.outCount = 0,
    this.outPct,
    this.deviation,
    this.trend,
    this.level = 'none',
  });

  static const WeightStats empty = WeightStats(count: 0);

  factory WeightStats.fromApi(Object? raw) {
    if (raw is! Map) return empty;
    final d = Map<String, dynamic>.from(raw);
    return WeightStats(
      count: _int(d['count']),
      avg: _dbl(d['avg']),
      min: _dbl(d['min']),
      max: _dbl(d['max']),
      std: _dbl(d['std']),
      lowCount: _int(d['low_count']),
      highCount: _int(d['high_count']),
      outCount: _int(d['out_count']),
      outPct: _dbl(d['out_pct']),
      deviation: _dbl(d['deviation']),
      trend: _txt(d['trend']),
      level: _txt(d['level']) ?? 'none',
    );
  }
}

/// نفس حساب السيرفر (weightStats) للمعاينة الفورية أثناء إدخال الأوزان فقط —
/// القيمة الرسمية يحسبها السيرفر عند الحفظ.
WeightStats mamoulLocalStats(
  List<double> weights, {
  double min = kMamoulWeightMin,
  double max = kMamoulWeightMax,
  double? target,
}) {
  final n = weights.length;
  if (n == 0) return WeightStats.empty;
  const eps = 1e-9;
  final sum = weights.fold<double>(0, (a, w) => a + w);
  final avg = sum / n;
  var std = 0.0;
  if (n > 1) {
    final sq = weights.fold<double>(0, (a, w) => a + (w - avg) * (w - avg));
    std = math.sqrt(sq / (n - 1));
  }
  final low = weights.where((w) => w < min - eps).length;
  final high = weights.where((w) => w > max + eps).length;
  final out = low + high;
  String? trend;
  if (avg >= max - kMamoulWarnMargin - eps) {
    trend = 'high';
  } else if (avg <= min + kMamoulWarnMargin + eps) {
    trend = 'low';
  }
  var level = 'ok';
  if (out > 0) {
    level = 'bad';
  } else if (trend != null) {
    level = 'warn';
  }
  return WeightStats(
    count: n,
    avg: avg,
    min: weights.reduce(math.min),
    max: weights.reduce(math.max),
    std: std,
    lowCount: low,
    highCount: high,
    outCount: out,
    outPct: out / n * 100,
    deviation: target == null ? null : avg - target,
    trend: trend,
    level: level,
  );
}

String mamoulLevelLabel(String level) {
  switch (level) {
    case 'ok':
      return 'ضمن النطاق';
    case 'warn':
      return 'قريب من الحد';
    case 'bad':
      return 'خارج النطاق';
    default:
      return 'لا عيّنات';
  }
}

/// جملة توضّح اتجاه الوزن (للتنبيه المبكر) أو null لو لا ميل.
String? mamoulTrendHint(String? trend) {
  if (trend == 'high') return 'المتوسط يقترب من الحد الأعلى — الوزن يميل للزيادة';
  if (trend == 'low') return 'المتوسط يقترب من الحد الأدنى — الوزن يميل للنقصان';
  return null;
}

// ---------------------------------------------------------------------------
// المكائن (أكثر من مكينة في منطقة المعمول)
// ---------------------------------------------------------------------------

class MamoulMachine {
  final String id;
  final String name;
  final String? code;
  final bool active;
  final int runsCount;
  final int faultsCount;
  final int faultsOpen;

  const MamoulMachine({
    required this.id,
    required this.name,
    this.code,
    required this.active,
    this.runsCount = 0,
    this.faultsCount = 0,
    this.faultsOpen = 0,
  });

  factory MamoulMachine.fromApi(Map<String, dynamic> d) => MamoulMachine(
        id: d['id'].toString(),
        name: (d['name'] as String?) ?? '',
        code: _txt(d['code']),
        active: d['active'] != false,
        runsCount: _int(d['runs_count']),
        faultsCount: _int(d['faults_count']),
        faultsOpen: _int(d['faults_open']),
      );

  /// يمكن حذفها نهائيًا فقط لو لا تشغيلات ولا أعطال عليها.
  bool get canDelete => runsCount == 0 && faultsCount == 0;

  /// "مكينة ١ (M1)" أو الاسم وحده.
  String get label => code == null ? name : '$name ($code)';

  static List<MamoulMachine> listFromApi(Object? raw) {
    final d = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final list = d['machines'] is List ? d['machines'] as List : const [];
    return list.map((e) => MamoulMachine.fromApi(Map<String, dynamic>.from(e as Map))).toList();
  }
}

// ---------------------------------------------------------------------------
// العيّنات والعيوب والسرعات والأعطال
// ---------------------------------------------------------------------------

class MamoulSample {
  final String id;
  final String runId;
  final String time;
  final double? speedBelt;
  final double? speedPush;
  final double? speedRotary;
  final String? note;
  final List<double> weights;
  final WeightStats stats;

  const MamoulSample({
    required this.id,
    required this.runId,
    required this.time,
    this.speedBelt,
    this.speedPush,
    this.speedRotary,
    this.note,
    required this.weights,
    required this.stats,
  });

  factory MamoulSample.fromApi(Map<String, dynamic> d) {
    final rawWeights = d['weights'];
    final weights = <double>[];
    if (rawWeights is List) {
      for (final w in rawWeights) {
        final v = _dbl(w);
        if (v != null) weights.add(v);
      }
    }
    return MamoulSample(
      id: d['id'].toString(),
      runId: d['run_id'].toString(),
      time: (d['sample_time'] as String?) ?? '',
      speedBelt: _dbl(d['speed_belt']),
      speedPush: _dbl(d['speed_push']),
      speedRotary: _dbl(d['speed_rotary']),
      note: _txt(d['note']),
      weights: weights,
      stats: WeightStats.fromApi(d['stats']),
    );
  }
}

class MamoulDefectEntry {
  final String id;
  final String time;
  final int twins;
  final int flash;
  final int rejected;
  final String? note;

  const MamoulDefectEntry({
    required this.id,
    required this.time,
    required this.twins,
    required this.flash,
    required this.rejected,
    this.note,
  });

  factory MamoulDefectEntry.fromApi(Map<String, dynamic> d) => MamoulDefectEntry(
        id: d['id'].toString(),
        time: (d['event_time'] as String?) ?? '',
        twins: _int(d['twins']),
        flash: _int(d['flash']),
        rejected: _int(d['rejected']),
        note: _txt(d['note']),
      );

  int get total => twins + flash + rejected;
}

class MamoulDefectTotals {
  final int twins;
  final int flash;
  final int rejected;
  final int total;
  final double? pctOfProduced;

  const MamoulDefectTotals({
    this.twins = 0,
    this.flash = 0,
    this.rejected = 0,
    this.total = 0,
    this.pctOfProduced,
  });

  factory MamoulDefectTotals.fromApi(Object? raw) {
    if (raw is! Map) return const MamoulDefectTotals();
    final d = Map<String, dynamic>.from(raw);
    return MamoulDefectTotals(
      twins: _int(d['twins']),
      flash: _int(d['flash']),
      rejected: _int(d['rejected']),
      total: _int(d['total']),
      pctOfProduced: _dbl(d['pct_of_produced']),
    );
  }
}

class MamoulSpeedChange {
  final String time;
  final double? belt;
  final double? push;
  final double? rotary;
  final String? reason;

  const MamoulSpeedChange({required this.time, this.belt, this.push, this.rotary, this.reason});

  factory MamoulSpeedChange.fromApi(Map<String, dynamic> d) => MamoulSpeedChange(
        time: (d['change_time'] as String?) ?? '',
        belt: _dbl(d['speed_belt']),
        push: _dbl(d['speed_push']),
        rotary: _dbl(d['speed_rotary']),
        reason: _txt(d['reason']),
      );
}

class MamoulFault {
  final String id;
  final String? machineId;
  final String? machineName;
  final String? runId;
  final String date;
  final String? time;
  final String component;
  final String? partLabel;
  final String description;
  final int? downtimeMinutes;
  final String? actionTaken;

  /// 'open' | 'resolved'
  final String status;
  final String? resolvedBy;

  const MamoulFault({
    required this.id,
    this.machineId,
    this.machineName,
    this.runId,
    required this.date,
    this.time,
    required this.component,
    this.partLabel,
    required this.description,
    this.downtimeMinutes,
    this.actionTaken,
    required this.status,
    this.resolvedBy,
  });

  factory MamoulFault.fromApi(Map<String, dynamic> d) => MamoulFault(
        id: d['id'].toString(),
        machineId: d['machine_id']?.toString(),
        machineName: _txt(d['machine_name']),
        runId: d['run_id']?.toString(),
        date: (d['fault_date'] as String?) ?? '',
        time: _txt(d['fault_time']),
        component: (d['component'] as String?) ?? 'other',
        partLabel: _txt(d['part_label']),
        description: (d['description'] as String?) ?? '',
        downtimeMinutes: d['downtime_minutes'] == null ? null : _int(d['downtime_minutes']),
        actionTaken: _txt(d['action_taken']),
        status: (d['status'] as String?) ?? 'open',
        resolvedBy: _txt(d['resolved_by']),
      );

  bool get isOpen => status == 'open';

  /// "بستون ٢" أو "بستون" لو لا تسمية.
  String get title {
    final base = mamoulComponentLabel(component);
    return partLabel == null ? base : '$base — $partLabel';
  }
}

class MamoulFaultsResult {
  final List<MamoulFault> faults;
  final int openCount;
  final int downtimeMinutes;
  final Map<String, int> byComponent;

  const MamoulFaultsResult({
    required this.faults,
    required this.openCount,
    required this.downtimeMinutes,
    required this.byComponent,
  });

  factory MamoulFaultsResult.fromApi(Object? raw) {
    final d = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final list = d['faults'] is List ? d['faults'] as List : const [];
    final by = <String, int>{};
    final rawBy = d['by_component'];
    if (rawBy is Map) {
      rawBy.forEach((k, v) => by[k.toString()] = _int(v));
    }
    return MamoulFaultsResult(
      faults: list.map((e) => MamoulFault.fromApi(Map<String, dynamic>.from(e as Map))).toList(),
      openCount: _int(d['open_count']),
      downtimeMinutes: _int(d['downtime_minutes']),
      byComponent: by,
    );
  }
}

// ---------------------------------------------------------------------------
// التشغيلة
// ---------------------------------------------------------------------------

class MamoulRunSummary {
  final int samplesCount;
  final int piecesCount;
  final WeightStats stats;
  final String? lastSampleLevel;
  final double? lastSampleAvg;
  final String? lastSampleTrend;
  final MamoulDefectTotals defects;
  final int faultsTotal;
  final int faultsOpen;

  const MamoulRunSummary({
    this.samplesCount = 0,
    this.piecesCount = 0,
    this.stats = WeightStats.empty,
    this.lastSampleLevel,
    this.lastSampleAvg,
    this.lastSampleTrend,
    this.defects = const MamoulDefectTotals(),
    this.faultsTotal = 0,
    this.faultsOpen = 0,
  });

  factory MamoulRunSummary.fromApi(Object? raw) {
    if (raw is! Map) return const MamoulRunSummary();
    final d = Map<String, dynamic>.from(raw);
    return MamoulRunSummary(
      samplesCount: _int(d['samples_count']),
      piecesCount: _int(d['pieces_count']),
      stats: WeightStats.fromApi(d['stats']),
      lastSampleLevel: _txt(d['last_sample_level']),
      lastSampleAvg: _dbl(d['last_sample_avg']),
      lastSampleTrend: _txt(d['last_sample_trend']),
      defects: MamoulDefectTotals.fromApi(d['defects']),
      faultsTotal: _int(d['faults_total']),
      faultsOpen: _int(d['faults_open']),
    );
  }
}

class MamoulRun {
  final String id;
  final String? machineId;
  final String? machineName;
  final String? machineCode;
  final String runDate;
  final String? shift;
  final double targetWeight;
  final double weightMin;
  final double weightMax;
  final String? startTime;
  final String? endTime;

  /// 'open' | 'closed'
  final String status;
  final String? operatorName;
  final String? pasteBatch;
  final String? moistureLevel;
  final double? moisturePct;
  final String speedUnit;
  final double? speedBelt;
  final double? speedPush;
  final double? speedRotary;
  final int? producedCount;
  final String? notes;
  final MamoulRunSummary summary;

  const MamoulRun({
    required this.id,
    this.machineId,
    this.machineName,
    this.machineCode,
    required this.runDate,
    this.shift,
    required this.targetWeight,
    required this.weightMin,
    required this.weightMax,
    this.startTime,
    this.endTime,
    required this.status,
    this.operatorName,
    this.pasteBatch,
    this.moistureLevel,
    this.moisturePct,
    required this.speedUnit,
    this.speedBelt,
    this.speedPush,
    this.speedRotary,
    this.producedCount,
    this.notes,
    required this.summary,
  });

  factory MamoulRun.fromApi(Map<String, dynamic> d) => MamoulRun(
        id: d['id'].toString(),
        machineId: d['machine_id']?.toString(),
        machineName: _txt(d['machine_name']),
        machineCode: _txt(d['machine_code']),
        runDate: (d['run_date'] as String?) ?? '',
        shift: _txt(d['shift']),
        targetWeight: _dbl(d['target_weight']) ?? 6.2,
        weightMin: _dbl(d['weight_min']) ?? kMamoulWeightMin,
        weightMax: _dbl(d['weight_max']) ?? kMamoulWeightMax,
        startTime: _txt(d['start_time']),
        endTime: _txt(d['end_time']),
        status: (d['status'] as String?) ?? 'open',
        operatorName: _txt(d['operator_name']),
        pasteBatch: _txt(d['paste_batch']),
        moistureLevel: _txt(d['paste_moisture_level']),
        moisturePct: _dbl(d['paste_moisture_pct']),
        speedUnit: (d['speed_unit'] as String?) ?? 'Hz',
        speedBelt: _dbl(d['speed_belt']),
        speedPush: _dbl(d['speed_push']),
        speedRotary: _dbl(d['speed_rotary']),
        producedCount: d['produced_count'] == null ? null : _int(d['produced_count']),
        notes: _txt(d['notes']),
        summary: MamoulRunSummary.fromApi(d['summary']),
      );

  bool get isOpen => status == 'open';

  /// اسم المكينة للعرض (تشغيلات قديمة بلا مكينة → "بدون مكينة").
  String get machineLabel => machineName ?? 'بدون مكينة';

  /// عنوان قصير للتشغيلة: "صباحي — هدف ٦٫٢".
  String get title {
    final shiftText = shift ?? 'تشغيلة';
    return '$shiftText — هدف ${mamoulNum(targetWeight)}';
  }
}

class MamoulRunDetail {
  final MamoulRun run;
  final List<MamoulSample> samples;
  final List<MamoulDefectEntry> defects;
  final List<MamoulFault> faults;
  final List<MamoulSpeedChange> speedChanges;

  const MamoulRunDetail({
    required this.run,
    required this.samples,
    required this.defects,
    required this.faults,
    required this.speedChanges,
  });

  static List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) f) {
    if (raw is! List) return <T>[];
    return raw.map((e) => f(Map<String, dynamic>.from(e as Map))).toList();
  }

  factory MamoulRunDetail.fromApi(Object? raw) {
    final d = Map<String, dynamic>.from(raw as Map);
    return MamoulRunDetail(
      run: MamoulRun.fromApi(Map<String, dynamic>.from(d['run'] as Map)),
      samples: _list(d['samples'], MamoulSample.fromApi),
      defects: _list(d['defects'], MamoulDefectEntry.fromApi),
      faults: _list(d['faults'], MamoulFault.fromApi),
      speedChanges: _list(d['speed_changes'], MamoulSpeedChange.fromApi),
    );
  }
}

/// إجماليات قائمة تشغيلات (تقرير اليوم).
class MamoulTotals {
  final int runsCount;
  final int openRunsCount;
  final int samplesCount;
  final int piecesCount;
  final double? avgWeight;
  final int outCount;
  final double? outPct;
  final int producedCount;
  final MamoulDefectTotals defects;
  final int faultsTotal;
  final int faultsOpen;

  const MamoulTotals({
    this.runsCount = 0,
    this.openRunsCount = 0,
    this.samplesCount = 0,
    this.piecesCount = 0,
    this.avgWeight,
    this.outCount = 0,
    this.outPct,
    this.producedCount = 0,
    this.defects = const MamoulDefectTotals(),
    this.faultsTotal = 0,
    this.faultsOpen = 0,
  });

  factory MamoulTotals.fromApi(Object? raw) {
    if (raw is! Map) return const MamoulTotals();
    final d = Map<String, dynamic>.from(raw);
    return MamoulTotals(
      runsCount: _int(d['runs_count']),
      openRunsCount: _int(d['open_runs_count']),
      samplesCount: _int(d['samples_count']),
      piecesCount: _int(d['pieces_count']),
      avgWeight: _dbl(d['avg_weight']),
      outCount: _int(d['out_count']),
      outPct: _dbl(d['out_pct']),
      producedCount: _int(d['produced_count']),
      defects: MamoulDefectTotals.fromApi(d['defects']),
      faultsTotal: _int(d['faults_total']),
      faultsOpen: _int(d['faults_open']),
    );
  }
}

class MamoulRunsResult {
  final List<MamoulRun> runs;
  final MamoulTotals totals;

  const MamoulRunsResult({required this.runs, required this.totals});

  factory MamoulRunsResult.fromApi(Object? raw) {
    final d = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final list = d['runs'] is List ? d['runs'] as List : const [];
    return MamoulRunsResult(
      runs: list.map((e) => MamoulRun.fromApi(Map<String, dynamic>.from(e as Map))).toList(),
      totals: MamoulTotals.fromApi(d['totals']),
    );
  }
}

// ---------------------------------------------------------------------------
// التحليل
// ---------------------------------------------------------------------------

/// نتيجة تركيبة سرعات (سير/دفع/دوار) عبر كل العيّنات المأخوذة بها.
class MamoulSpeedGroup {
  final String? machineId;
  final String? machineName;
  final String speedUnit;
  final double? speedBelt;
  final double? speedPush;
  final double? speedRotary;
  final double targetWeight;
  final int samplesCount;
  final int runsCount;
  final int pieces;
  final double avg;
  final double? min;
  final double? max;
  final double std;
  final double outPct;
  final double deviation;
  final bool enoughData;

  const MamoulSpeedGroup({
    this.machineId,
    this.machineName,
    required this.speedUnit,
    this.speedBelt,
    this.speedPush,
    this.speedRotary,
    required this.targetWeight,
    required this.samplesCount,
    required this.runsCount,
    required this.pieces,
    required this.avg,
    this.min,
    this.max,
    required this.std,
    required this.outPct,
    required this.deviation,
    required this.enoughData,
  });

  factory MamoulSpeedGroup.fromApi(Map<String, dynamic> d) => MamoulSpeedGroup(
        machineId: d['machine_id']?.toString(),
        machineName: _txt(d['machine_name']),
        speedUnit: (d['speed_unit'] as String?) ?? 'Hz',
        speedBelt: _dbl(d['speed_belt']),
        speedPush: _dbl(d['speed_push']),
        speedRotary: _dbl(d['speed_rotary']),
        targetWeight: _dbl(d['target_weight']) ?? 6.2,
        samplesCount: _int(d['samples_count']),
        runsCount: _int(d['runs_count']),
        pieces: _int(d['pieces']),
        avg: _dbl(d['avg']) ?? 0,
        min: _dbl(d['min']),
        max: _dbl(d['max']),
        std: _dbl(d['std']) ?? 0,
        outPct: _dbl(d['out_pct']) ?? 0,
        deviation: _dbl(d['deviation']) ?? 0,
        enoughData: d['enough_data'] == true,
      );
}

/// إحصاءات مجموعة بحسب دفعة العجينة أو درجة رطوبتها.
class MamoulGroupStat {
  final String label;
  final int runsCount;
  final int samplesCount;
  final int pieces;
  final double avg;
  final double std;
  final double outPct;

  const MamoulGroupStat({
    required this.label,
    required this.runsCount,
    required this.samplesCount,
    required this.pieces,
    required this.avg,
    required this.std,
    required this.outPct,
  });

  factory MamoulGroupStat.fromApi(Map<String, dynamic> d, String labelKey) => MamoulGroupStat(
        label: (d[labelKey] ?? '').toString(),
        runsCount: _int(d['runs_count']),
        samplesCount: _int(d['samples_count']),
        pieces: _int(d['pieces']),
        avg: _dbl(d['avg']) ?? 0,
        std: _dbl(d['std']) ?? 0,
        outPct: _dbl(d['out_pct']) ?? 0,
      );
}

/// صف مقارنة بين المكائن: جودة الوزن والعيوب والأعطال لكل مكينة في المدة المختارة.
class MamoulMachineComparison {
  final String machineId;
  final String machineName;
  final bool active;
  final int runsCount;
  final int samplesCount;
  final int pieces;
  final double? avg;
  final double? std;
  final double? outPct;
  final MamoulDefectTotals defects;
  final int producedCount;
  final double? defectPct;
  final int faultsTotal;
  final int faultsOpen;
  final int downtimeMinutes;

  const MamoulMachineComparison({
    required this.machineId,
    required this.machineName,
    required this.active,
    required this.runsCount,
    required this.samplesCount,
    required this.pieces,
    this.avg,
    this.std,
    this.outPct,
    required this.defects,
    required this.producedCount,
    this.defectPct,
    required this.faultsTotal,
    required this.faultsOpen,
    required this.downtimeMinutes,
  });

  factory MamoulMachineComparison.fromApi(Map<String, dynamic> d) => MamoulMachineComparison(
        machineId: d['machine_id'].toString(),
        machineName: (d['machine_name'] as String?) ?? '',
        active: d['active'] != false,
        runsCount: _int(d['runs_count']),
        samplesCount: _int(d['samples_count']),
        pieces: _int(d['pieces']),
        avg: _dbl(d['avg']),
        std: _dbl(d['std']),
        outPct: _dbl(d['out_pct']),
        defects: MamoulDefectTotals.fromApi(d['defects']),
        producedCount: _int(d['produced_count']),
        defectPct: _dbl(d['defect_pct']),
        faultsTotal: _int(d['faults_total']),
        faultsOpen: _int(d['faults_open']),
        downtimeMinutes: _int(d['downtime_minutes']),
      );
}

class MamoulAnalysis {
  final int samplesCount;

  /// المكينة التي حُصر التحليل عليها (null = كل المكائن).
  final String? machineId;
  final List<MamoulSpeedGroup> speeds;
  final List<MamoulSpeedGroup> recommended;
  final List<MamoulGroupStat> byBatch;
  final List<MamoulGroupStat> byMoisture;
  final List<MamoulMachineComparison> machines;

  const MamoulAnalysis({
    required this.samplesCount,
    this.machineId,
    required this.speeds,
    required this.recommended,
    required this.byBatch,
    required this.byMoisture,
    required this.machines,
  });

  factory MamoulAnalysis.fromApi(Object? raw) {
    final d = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    List<MamoulSpeedGroup> groups(Object? v) => v is List
        ? v.map((e) => MamoulSpeedGroup.fromApi(Map<String, dynamic>.from(e as Map))).toList()
        : <MamoulSpeedGroup>[];
    List<MamoulGroupStat> stats(Object? v, String key) => v is List
        ? v.map((e) => MamoulGroupStat.fromApi(Map<String, dynamic>.from(e as Map), key)).toList()
        : <MamoulGroupStat>[];
    List<MamoulMachineComparison> comparison(Object? v) => v is List
        ? v.map((e) => MamoulMachineComparison.fromApi(Map<String, dynamic>.from(e as Map))).toList()
        : <MamoulMachineComparison>[];
    return MamoulAnalysis(
      samplesCount: _int(d['samples_count']),
      machineId: d['machine_id']?.toString(),
      speeds: groups(d['speeds']),
      recommended: groups(d['recommended']),
      byBatch: stats(d['by_batch'], 'paste_batch'),
      byMoisture: stats(d['by_moisture'], 'paste_moisture_level'),
      machines: comparison(d['machines']),
    );
  }
}

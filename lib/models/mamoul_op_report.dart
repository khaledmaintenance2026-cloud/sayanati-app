import 'dart:convert';
import 'dart:typed_data';

import '../services/arabic_format.dart';

/// نماذج «تقرير تشغيل المعمول» (Mamoul Operating Report — QMS-PD-006 REV:004):
/// النسخة الإلكترونية من الورقة التي تُعبّأ في منطقة المعمول (الإنتاج، مصنع
/// النساء). تصل من سيرفر صيانتي عبر /api/mamoul-reports (راجع
/// routes/mamoulOperatingReports.js). وزن الدفعة بالجرام (قرار المالك 2026-11-05).

String? _txt(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

int _int(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

double? _dbl(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

Map<String, dynamic> _map(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<dynamic> _list(Object? v) => v is List ? v : const <dynamic>[];

Uint8List? _png(Object? v) {
  final s = _txt(v);
  if (s == null) return null;
  try {
    return base64Decode(s);
  } catch (_) {
    return null;
  }
}

DateTime? _time(Object? v) {
  final s = _txt(v);
  if (s == null) return null;
  return DateTime.tryParse(s)?.toLocal();
}

/// اسمان متطابقان؟ (بلا مسافات زائدة وبلا فرق حروف كبيرة/صغيرة).
bool mamoulSameName(String? a, String? b) {
  final x = (a ?? '').trim().toLowerCase();
  final y = (b ?? '').trim().toLowerCase();
  return x.isNotEmpty && x == y;
}

/// عاملة في قائمة عاملات المعمول الثابتة.
class MamoulWorker {
  final String id;
  final String name;
  final String? employeeNumber;
  final bool active;
  final int usedCount;

  const MamoulWorker({
    required this.id,
    required this.name,
    this.employeeNumber,
    required this.active,
    this.usedCount = 0,
  });

  factory MamoulWorker.fromApi(Map<String, dynamic> d) => MamoulWorker(
        id: d['id'].toString(),
        name: (d['name'] ?? '').toString(),
        employeeNumber: _txt(d['employee_number']),
        active: d['active'] != false,
        usedCount: _int(d['used_count']),
      );

  static List<MamoulWorker> listFromApi(dynamic data) =>
      _list(_map(data)['workers']).map((e) => MamoulWorker.fromApi(_map(e))).toList();

  /// الاسم مع الرقم الوظيفي (للتمييز بين الأسماء المتشابهة مثل «فاطمة»).
  String get label => employeeNumber == null ? name : '$name ($employeeNumber)';
}

/// عاملة داخل تقرير: من القائمة ([workerId]) أو اسم مكتوب فقط.
class MamoulOpWorkerEntry {
  final String? workerId;
  final String name;
  final String? employeeNumber;

  const MamoulOpWorkerEntry({this.workerId, required this.name, this.employeeNumber});

  factory MamoulOpWorkerEntry.fromApi(Map<String, dynamic> d) => MamoulOpWorkerEntry(
        workerId: d['worker_id'] == null ? null : d['worker_id'].toString(),
        name: (d['name'] ?? '').toString(),
        employeeNumber: _txt(d['employee_number']),
      );

  factory MamoulOpWorkerEntry.ofWorker(MamoulWorker w) =>
      MamoulOpWorkerEntry(workerId: w.id, name: w.name, employeeNumber: w.employeeNumber);

  Map<String, dynamic> toApi() => {
        if (workerId != null) 'workerId': workerId,
        'name': name,
      };

  String get label => employeeNumber == null ? name : '$name ($employeeNumber)';
}

/// مجموعة مكائن (مثل «302 - 305») والعاملات عليها — عمودان في جدول الورقة.
class MamoulOpGroup {
  final String machines;
  final List<MamoulOpWorkerEntry> workers;

  const MamoulOpGroup({required this.machines, required this.workers});

  factory MamoulOpGroup.fromApi(Map<String, dynamic> d) => MamoulOpGroup(
        machines: (d['machines'] ?? '').toString(),
        workers: _list(d['workers']).map((e) => MamoulOpWorkerEntry.fromApi(_map(e))).toList(),
      );

  Map<String, dynamic> toApi() => {
        'machines': machines,
        'workers': workers.map((w) => w.toApi()).toList(),
      };
}

class MamoulOpReport {
  final String id;
  final String productName;
  final String batchNo;

  /// تاريخ تكوير الكرات 'YYYY-MM-DD'.
  final String ballMakeDate;

  /// وزن الدفعة بالجرام.
  final double? batchWeightG;
  final String? startTime;
  final String? endTime;
  final String? notes;
  final String? operatorName;
  final bool hasSignature;
  final bool canEdit;
  final String? createdBy;
  final DateTime? createdAt;
  final String? updatedBy;
  final List<MamoulOpGroup> groups;

  /// صورة التوقيع (تصل فقط في تفاصيل تقرير واحد).
  final Uint8List? signaturePng;

  const MamoulOpReport({
    required this.id,
    required this.productName,
    required this.batchNo,
    required this.ballMakeDate,
    this.batchWeightG,
    this.startTime,
    this.endTime,
    this.notes,
    this.operatorName,
    required this.hasSignature,
    required this.canEdit,
    this.createdBy,
    this.createdAt,
    this.updatedBy,
    required this.groups,
    this.signaturePng,
  });

  factory MamoulOpReport.fromApi(Map<String, dynamic> d) => MamoulOpReport(
        id: d['id'].toString(),
        productName: (d['product_name'] ?? '').toString(),
        batchNo: (d['batch_no'] ?? '').toString(),
        ballMakeDate: (d['ball_make_date'] ?? '').toString(),
        batchWeightG: _dbl(d['batch_weight_g']),
        startTime: _txt(d['start_time']),
        endTime: _txt(d['end_time']),
        notes: _txt(d['notes']),
        operatorName: _txt(d['operator_name']),
        hasSignature: d['has_signature'] == true,
        canEdit: d['can_edit'] == true,
        createdBy: _txt(d['created_by']),
        createdAt: _time(d['created_at']),
        updatedBy: _txt(d['updated_by']),
        groups: _list(d['groups']).map((e) => MamoulOpGroup.fromApi(_map(e))).toList(),
        signaturePng: _png(d['signature_png']),
      );

  int get workersCount => groups.fold<int>(0, (sum, g) => sum + g.workers.length);

  String get machinesLine {
    final parts = groups.map((g) => g.machines.trim()).where((m) => m.isNotEmpty).toList();
    return parts.isEmpty ? '—' : parts.join(' · ');
  }
}

class MamoulOpReportsResult {
  final List<MamoulOpReport> reports;
  final int count;
  final double weightG;

  const MamoulOpReportsResult({required this.reports, required this.count, required this.weightG});

  factory MamoulOpReportsResult.fromApi(dynamic data) {
    final d = _map(data);
    final totals = _map(d['totals']);
    final reports = _list(d['reports']).map((e) => MamoulOpReport.fromApi(_map(e))).toList();
    return MamoulOpReportsResult(
      reports: reports,
      count: totals['count'] == null ? reports.length : _int(totals['count']),
      weightG: _dbl(totals['weight_g']) ?? 0,
    );
  }
}

/// توقيع محفوظ لمشغّلة (الصورة تصل فقط لتوقيع المشغّلة الافتراضية).
class MamoulSignatureInfo {
  final String id;
  final String operatorName;
  final String? createdBy;
  final DateTime? createdAt;
  final Uint8List? png;

  const MamoulSignatureInfo({
    required this.id,
    required this.operatorName,
    this.createdBy,
    this.createdAt,
    this.png,
  });

  factory MamoulSignatureInfo.fromApi(Map<String, dynamic> d) => MamoulSignatureInfo(
        id: d['id'].toString(),
        operatorName: (d['operator_name'] ?? '').toString(),
        createdBy: _txt(d['created_by']),
        createdAt: _time(d['created_at']),
        png: _png(d['png']),
      );
}

/// إعدادات شاشة تقارير التشغيل كما يرسلها السيرفر (ومنها صلاحيات المستخدم الحالي).
class MamoulOpConfig {
  final bool canWrite;
  final bool canManage;
  final String defaultOperator;
  final String defaultProduct;
  final MamoulSignatureInfo? signature;
  final List<MamoulSignatureInfo> signatures;

  const MamoulOpConfig({
    required this.canWrite,
    required this.canManage,
    required this.defaultOperator,
    required this.defaultProduct,
    this.signature,
    this.signatures = const [],
  });

  factory MamoulOpConfig.fromApi(dynamic data) {
    final d = _map(data);
    final sig = d['signature'];
    return MamoulOpConfig(
      canWrite: d['can_write'] == true,
      canManage: d['can_manage'] == true,
      defaultOperator: _txt(d['default_operator']) ?? 'فاطمة',
      defaultProduct: _txt(d['default_product']) ?? 'معمول كويتي',
      signature: sig is Map ? MamoulSignatureInfo.fromApi(_map(sig)) : null,
      signatures: _list(d['signatures']).map((e) => MamoulSignatureInfo.fromApi(_map(e))).toList(),
    );
  }

  /// هل لهذا الاسم توقيع محفوظ فعّال؟
  bool hasSignatureFor(String? name) => signatures.any((s) => mamoulSameName(s.operatorName, name));

  /// صورة التوقيع لهذا الاسم لو كانت متوفرة (للمشغّلة الافتراضية فقط).
  Uint8List? signaturePngFor(String? name) {
    final s = signature;
    if (s == null || !mamoulSameName(s.operatorName, name)) return null;
    return s.png;
  }
}

/// بيانات تقرير قبل الحفظ (إنشاء أو تعديل).
class MamoulOpReportDraft {
  final String productName;
  final String batchNo;
  final String ballMakeDate;
  final double? batchWeightG;
  final String? startTime;
  final String? endTime;
  final String? notes;
  final String? operatorName;
  final bool useSignature;
  final List<MamoulOpGroup> groups;

  const MamoulOpReportDraft({
    required this.productName,
    required this.batchNo,
    required this.ballMakeDate,
    this.batchWeightG,
    this.startTime,
    this.endTime,
    this.notes,
    this.operatorName,
    required this.useSignature,
    required this.groups,
  });

  Map<String, dynamic> toApi() => {
        'productName': productName,
        'batchNo': batchNo,
        'ballMakeDate': ballMakeDate,
        'batchWeightG': batchWeightG,
        'startTime': startTime,
        'endTime': endTime,
        'notes': notes,
        'operatorName': operatorName,
        'useSignature': useSignature,
        'groups': groups.map((g) => g.toApi()).toList(),
      };
}

// ---------------------------------------------------------------------------
// تنسيق الأرقام
// ---------------------------------------------------------------------------

/// يجمّع الجزء الصحيح بفاصل آلاف: '280500' → '280,500'.
String _groupThousands(String digits) {
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    b.write(digits[i]);
    final left = digits.length - i - 1;
    if (left > 0 && left % 3 == 0) b.write(',');
  }
  return b.toString();
}

/// رقم بفاصل آلاف ومنازل عشرية حتى [decimals] (بلا أصفار زائدة)، بأرقام هندية:
/// 280500 → '٢٨٠٬٥٠٠'، 280.5 → '٢٨٠٫٥'.
String mamoulGroupedNumber(double v, {int decimals = 3}) {
  var s = v.toStringAsFixed(decimals);
  if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '');
    s = s.replaceFirst(RegExp(r'\.$'), '');
  }
  final parts = s.split('.');
  final grouped = _groupThousands(parts[0]) + (parts.length > 1 ? '.${parts[1]}' : '');
  return ArabicFormat.toEasternDigits(grouped).replaceAll(',', '٬').replaceAll('.', '٫');
}

/// وزن الدفعة: '٢٨٠٬٥٠٠ جم' أو '—'.
String mamoulGramsText(double? g) => g == null ? '—' : '${mamoulGroupedNumber(g)} جم';

/// نفس الوزن بالكيلو للتوضيح: '٢٨٠٫٥ كجم'.
String mamoulKgText(double? g) => g == null ? '—' : '${mamoulGroupedNumber(g / 1000)} كجم';

/// يقرأ وزنًا بالجرام كما تكتبه العاملة: أرقام لاتينية أو هندية، والفاصلة
/// (, ، ٬) فاصل آلاف، و'.' أو '٫' فاصلة عشرية. فارغ → null، غير صالح → NaN.
double? mamoulParseGrams(String raw) {
  var s = raw.trim();
  if (s.isEmpty) return null;
  const eastern = '٠١٢٣٤٥٦٧٨٩';
  final b = StringBuffer();
  for (final ch in s.split('')) {
    final i = eastern.indexOf(ch);
    if (i >= 0) {
      b.write(i);
    } else if (ch == ',' || ch == '،' || ch == '٬' || ch == ' ') {
      continue;
    } else if (ch == '٫') {
      b.write('.');
    } else {
      b.write(ch);
    }
  }
  s = b.toString();
  return double.tryParse(s) ?? double.nan;
}

class ProductionLine {
  final String id;
  String name;
  String location;
  bool activeToday;

  ProductionLine({
    required this.id,
    required this.name,
    this.location = 'المستودع العام',
    this.activeToday = true,
  });

  /// يبني خط إنتاج من استجابة سيرفر صيانتي المحلي (جدول production_lines).
  factory ProductionLine.fromApi(Map<String, dynamic> d) => ProductionLine(
        id: d['id'].toString(),
        name: (d['name'] as String?) ?? '',
        location: (d['location'] as String?) ?? 'المستودع العام',
        activeToday: (d['active'] as bool?) ?? true,
      );
}

class Batch {
  final String id;
  final String lineId;
  final String batchNumber; // رقم الباتش — يكتبه المشرف يدويًا (ليس مولَّدًا تلقائيًا)
  final String productName;
  final int quantity;
  final DateTime date;
  final bool hasStoppage;
  final String? stoppageReason;
  final int? stoppageMinutes;
  final String? operationalNotes; // الملاحظات التشغيلية — عامة، مستقلة عن وجود توقف
  final String? actionsTaken; // الحلول والإجراءات المتخذة عند التوقف
  final String recordedBy; // مشرف الخط
  final int? workersCount; // عدد العمال على هذا الباتش — لمطابقة عمود "workers" في التقرير الأسبوعي القديم

  /// وقت بدء/انتهاء الباتش الفعلي (وقت اليوم فقط، مثل "08:00:00") — اختياري،
  /// يظهر في رسالة واتساب تسجيل الباتش (TIME FROM / TIME TO).
  final String? timeFrom;
  final String? timeTo;

  /// "طرق تجنّب تكرار المشكلة" — منفصلة عن [actionsTaken]، تُعبَّأ فقط عند
  /// وجود توقف. تظهر في رسالة واتساب كـ"Avoidance methods".
  final String? preventionMethods;

  Batch({
    required this.id,
    required this.lineId,
    required this.batchNumber,
    required this.productName,
    required this.quantity,
    required this.date,
    this.hasStoppage = false,
    this.stoppageReason,
    this.stoppageMinutes,
    this.operationalNotes,
    this.actionsTaken,
    required this.recordedBy,
    this.workersCount,
    this.timeFrom,
    this.timeTo,
    this.preventionMethods,
  });

  /// يبني باتشًا من استجابة سيرفر صيانتي المحلي (جدول production_batches) —
  /// كانت الباتشات محلية فقط على جهاز المشرف قبل هذا التحديث.
  factory Batch.fromApi(Map<String, dynamic> d) => Batch(
        id: d['id'].toString(),
        lineId: d['line_id'].toString(),
        batchNumber: (d['batch_number'] as String?) ?? '',
        productName: (d['product_name'] as String?) ?? '',
        quantity: ((d['quantity'] as num?) ?? 0).round(),
        date: DateTime.tryParse(d['created_at']?.toString() ?? '') ?? DateTime.now(),
        hasStoppage: (d['has_stoppage'] as bool?) ?? false,
        stoppageReason: d['stoppage_reason'] as String?,
        stoppageMinutes: (d['stoppage_minutes'] as num?)?.round(),
        operationalNotes: d['operational_notes'] as String?,
        actionsTaken: d['actions_taken'] as String?,
        recordedBy: (d['recorded_by'] as String?) ?? '',
        workersCount: (d['workers_count'] as num?)?.round(),
        timeFrom: d['time_from'] as String?,
        timeTo: d['time_to'] as String?,
        preventionMethods: d['prevention_methods'] as String?,
      );
}

/// بلاغ عطل/توقف فوري في الإنتاج — مرتبط بمسارات /production/incidents
/// الموجودة فعليًا على سيرفر صيانتي المحلي (جدول incident_reports).
class Incident {
  final String id;
  final String? lineId;
  final String? lineName;
  final String? equipmentId;
  final String? equipmentName;
  final String description;
  final String reportedBy;
  final DateTime reportedAt;
  final DateTime downtimeStartedAt;
  final DateTime? downtimeEndedAt;
  final String status; // open | linked | closed
  final int downtimeMinutes;

  /// تصنيف حدة العطل عند رفع البلاغ: simple (بسيط) / medium (متوسط) /
  /// critical (حرج) — اختياري، null للبلاغات القديمة قبل إضافة هذا الحقل.
  final String? severity;

  Incident({
    required this.id,
    this.lineId,
    this.lineName,
    this.equipmentId,
    this.equipmentName,
    required this.description,
    required this.reportedBy,
    required this.reportedAt,
    required this.downtimeStartedAt,
    this.downtimeEndedAt,
    required this.status,
    required this.downtimeMinutes,
    this.severity,
  });

  bool get isOpen => status == 'open';

  /// تسمية عربية جاهزة للعرض — بسيط/متوسط/حرج، أو null لو لم يُحدَّد.
  String? get severityLabel => switch (severity) {
        'simple' => 'بسيط',
        'medium' => 'متوسط',
        'critical' => 'حرج',
        _ => null,
      };

  factory Incident.fromApi(Map<String, dynamic> d) => Incident(
        id: d['id'].toString(),
        lineId: d['line_id']?.toString(),
        lineName: d['line_name'] as String?,
        equipmentId: d['equipment_id']?.toString(),
        equipmentName: d['equipment_name'] as String?,
        description: (d['description'] as String?) ?? '',
        reportedBy: (d['reported_by'] as String?) ?? '',
        reportedAt: DateTime.tryParse(d['reported_at']?.toString() ?? '') ?? DateTime.now(),
        downtimeStartedAt:
            DateTime.tryParse(d['downtime_started_at']?.toString() ?? '') ?? DateTime.now(),
        downtimeEndedAt: d['downtime_ended_at'] == null
            ? null
            : DateTime.tryParse(d['downtime_ended_at'].toString()),
        status: (d['status'] as String?) ?? 'open',
        downtimeMinutes: ((d['downtime_minutes'] as num?) ?? 0).round(),
        severity: d['severity'] as String?,
      );
}

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
  });
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
  });

  bool get isOpen => status == 'open';

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
      );
}

/// نوع أمر العمل: بلاغ عطل طارئ يرفعه الإنتاج، أو عمل آخر/وقائي يبادر به مشرف الصيانة.
enum MaintenanceKind { emergency, preventive }

enum MaintenanceStatus { pendingAssignment, inProgress, completed }

class MaintenanceReport {
  final String id;
  final String equipment;
  final String line; // الخط / الموقع
  final String description;
  final MaintenanceKind kind;
  MaintenanceStatus status;

  final String reportedBy;
  final DateTime reportedAt;

  List<String> assignedTechnicianIds;
  DateTime? assignedAt;

  String? closeDescription;
  String? partsUsed;
  DateTime? closedAt;

  /// للأعمال الوقائية فقط: كل كم يوم يُذكَّر المسؤول بإعادة فتح هذا العمل.
  final int? reminderIntervalDays;

  MaintenanceReport({
    required this.id,
    required this.equipment,
    required this.line,
    required this.description,
    required this.kind,
    this.status = MaintenanceStatus.pendingAssignment,
    required this.reportedBy,
    required this.reportedAt,
    List<String>? assignedTechnicianIds,
    this.assignedAt,
    this.closeDescription,
    this.partsUsed,
    this.closedAt,
    this.reminderIntervalDays,
  }) : assignedTechnicianIds = assignedTechnicianIds ?? [];

  /// المدة الزمنية من لحظة رفع البلاغ إلى لحظة إغلاقه — يحسبها التطبيق تلقائيًا،
  /// وليس على الفني إدخالها يدويًا.
  Duration? get duration {
    if (closedAt == null) return null;
    return closedAt!.difference(reportedAt);
  }

  bool get isEmergency => kind == MaintenanceKind.emergency;
}

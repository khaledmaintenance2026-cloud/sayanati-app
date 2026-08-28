enum PermitStatus { pending, approved, rejected }

class SafetyPermit {
  final String id;
  final String requesterName;
  final String requesterRole;
  final String location;
  final String description;
  final int techniciansCount;

  /// ربط اختياري ببلاغ صيانة قائم — إن وُجد بلاغ عند طلب التصريح.
  final String? relatedReportId;

  PermitStatus status;
  String? reviewedBy; // من قسم السلامة فقط
  DateTime? reviewedAt;

  final String requestedBy;
  final DateTime requestedAt;

  SafetyPermit({
    required this.id,
    required this.requesterName,
    required this.requesterRole,
    required this.location,
    required this.description,
    required this.techniciansCount,
    this.relatedReportId,
    this.status = PermitStatus.pending,
    this.reviewedBy,
    this.reviewedAt,
    required this.requestedBy,
    required this.requestedAt,
  });
}

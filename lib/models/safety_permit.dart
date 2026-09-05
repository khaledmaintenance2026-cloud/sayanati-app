enum PermitStatus { pending, approved, rejected }

/// خيارات "خلو الموقع من التالي" — تُعبَّأ من قسم السلامة قبل القبول فقط،
/// مطابقة تمامًا لاستمارة "إجراءات ومتطلبات السلامة لتصريح العمل" الورقية.
/// يمكن اختيار أكثر من عنصر.
const List<String> kSiteHazardOptions = [
  'تتطلب مراجعة من قبل قسم السلامة',
  'مواد قابلة للاشتعال',
  'المنتجات',
  'العاملين',
  'الحواجز',
  'انسكاب ماء/زيوت',
  'معدات غير آمنة',
  'الضوضاء',
];

/// خيارات "المخاطر المحتملة" — تُعبَّأ عند القبول فقط. يمكن اختيار أكثر من عنصر.
const List<String> kPotentialRiskOptions = [
  'سقوط معدات / عاملين',
  'انزلاق / تعثر',
  'خلل في التهوية / الإضاءة',
  'خلل في المعدات',
  'صعق كهربائي',
  'حروق',
];

/// خيارات "معدات الوقاية الشخصية التي يجب توفرها" — تُعبَّأ عند القبول فقط.
/// يمكن اختيار أكثر من عنصر، بالإضافة لخيار "أخرى" بنص حر في الشاشة.
const List<String> kPpeOptions = [
  'حذاء سلامة',
  'نظارة عاكسة',
  'خوذة رأس',
  'بطانية حريق',
  'بطانية لحام',
  'سروال مقاوم للحريق',
  'قفازات مقاومة',
  'حزام الأمان',
  'طفاية حريق',
  'معدات ميكانيكية يوجد بها حماية',
];

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

  // ---------------------------------------------------------------------
  // "قسم القبول" — تُعبَّأ فقط عند الموافقة على التصريح، مطابقة لاستمارة
  // "إجراءات ومتطلبات السلامة لتصريح العمل" (نفس أسماء الحقول المستخدَمة في
  // مسار /production... لا، بل في PATCH /safety-permits/:id/review على
  // سيرفر صيانتي المحلي: siteHazards, potentialRisks, ppeRequired, precautions).
  // ---------------------------------------------------------------------
  List<String> siteHazards;
  List<String> potentialRisks;
  List<String> ppeRequired;
  String? precautions; // الإجراءات الإلزامية للتصريح العمل

  // ---------------------------------------------------------------------
  // "قسم الرفض" — يُعبَّأ فقط عند رفض التصريح.
  // ---------------------------------------------------------------------
  String? rejectionReason;

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
    this.siteHazards = const [],
    this.potentialRisks = const [],
    this.ppeRequired = const [],
    this.precautions,
    this.rejectionReason,
    required this.requestedBy,
    required this.requestedAt,
  });
}

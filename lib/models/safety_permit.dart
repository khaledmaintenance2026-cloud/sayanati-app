enum PermitStatus { pending, approved, rejected }

PermitStatus _statusFromApi(String? s) => switch (s) {
      'approved' => PermitStatus.approved,
      'rejected' => PermitStatus.rejected,
      _ => PermitStatus.pending,
    };

/// أنواع الأعمال الخطرة — نفس القيم بالضبط المستخدمة في عمود operation_types
/// على السيرفر (راجع routes/safetyPermits.js، OPERATION_TYPES) والتسميات
/// المعروضة في رسائل واتساب (services/notifications.js، OPERATION_TYPE_LABELS)
/// — يجب أن يبقى المفتاح مطابقًا حرفيًا بين الطرفين.
const Map<String, String> kOperationTypeLabels = {
  'hot_work': 'أعمال حرارية/لحام',
  'confined_space': 'أماكن مغلقة',
  'height': 'العمل على مرتفعات',
  'electrical': 'كهرباء',
  'excavation': 'حفريات',
  'lifting': 'أعمال رفع',
  'other': 'أخرى',
};

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
  final String? officeName;
  final String location;
  final String description;
  final int workersCount;
  final String? responsiblePhone;
  final List<String> operationTypes;
  final String? equipmentUsed;

  /// مسار نسبي على السيرفر (مثال: /uploads/safety-permits/xxx.jpg) — يُبنى
  /// الرابط الكامل للعرض بإضافة عنوان السيرفر الأساسي (راجع ApiClient.baseUrl).
  final String? equipmentPhoto;

  final DateTime? startAt;
  final DateTime? endAt;

  final String requesterName; // من requested_by (اسم مقدّم الطلب وقت التقديم)

  /// ربط اختياري ببلاغ/أمر عمل صيانة قائم — إن وُجد بلاغ عند طلب التصريح.
  final String? relatedWorkOrderId;

  PermitStatus status;
  String? reviewedBy; // من قسم السلامة فقط
  DateTime? reviewedAt;

  // ---------------------------------------------------------------------
  // "قسم القبول" — تُعبَّأ فقط عند الموافقة على التصريح، مطابقة لاستمارة
  // "إجراءات ومتطلبات السلامة لتصريح العمل" (نفس أسماء الحقول المستخدَمة في
  // PATCH /safety-permits/:id/review على سيرفر صيانتي المحلي: siteHazards,
  // potentialRisks, ppeRequired, precautions).
  // ---------------------------------------------------------------------
  List<String> siteHazards;
  List<String> potentialRisks;
  List<String> ppeRequired;
  String? precautions; // الإجراءات الإلزامية للتصريح العمل

  // ---------------------------------------------------------------------
  // "قسم الرفض" — يُعبَّأ فقط عند رفض التصريح.
  // ---------------------------------------------------------------------
  String? rejectionReason;

  final DateTime requestedAt;

  SafetyPermit({
    required this.id,
    this.officeName,
    required this.location,
    required this.description,
    required this.workersCount,
    this.responsiblePhone,
    this.operationTypes = const [],
    this.equipmentUsed,
    this.equipmentPhoto,
    this.startAt,
    this.endAt,
    required this.requesterName,
    this.relatedWorkOrderId,
    this.status = PermitStatus.pending,
    this.reviewedBy,
    this.reviewedAt,
    this.siteHazards = const [],
    this.potentialRisks = const [],
    this.ppeRequired = const [],
    this.precautions,
    this.rejectionReason,
    required this.requestedAt,
  });

  /// يبني تصريحًا من استجابة سيرفر صيانتي المحلي (حقل "permit" في ردود
  /// GET/POST/PATCH /api/safety-permits) — الشكل: صفوف جدول safety_permits
  /// كما هي (snake_case)، راجع routes/safetyPermits.js.
  factory SafetyPermit.fromApi(Map<String, dynamic> d) => SafetyPermit(
        id: d['id'].toString(),
        officeName: d['office_name'] as String?,
        location: (d['location'] as String?) ?? '',
        description: (d['description'] as String?) ?? '',
        workersCount: (d['workers_count'] as num?)?.toInt() ?? 1,
        responsiblePhone: d['responsible_phone'] as String?,
        operationTypes: (d['operation_types'] as List?)?.cast<String>() ?? const [],
        equipmentUsed: d['equipment_used'] as String?,
        equipmentPhoto: d['equipment_photo'] as String?,
        startAt: d['start_at'] != null ? DateTime.tryParse(d['start_at'] as String) : null,
        endAt: d['end_at'] != null ? DateTime.tryParse(d['end_at'] as String) : null,
        requesterName: (d['requested_by'] as String?) ?? '',
        relatedWorkOrderId: d['related_work_order_id']?.toString(),
        status: _statusFromApi(d['status'] as String?),
        reviewedBy: d['reviewed_by'] as String?,
        reviewedAt: d['reviewed_at'] != null ? DateTime.tryParse(d['reviewed_at'] as String) : null,
        siteHazards: (d['site_hazards'] as List?)?.cast<String>() ?? const [],
        potentialRisks: (d['potential_risks'] as List?)?.cast<String>() ?? const [],
        ppeRequired: (d['ppe_required'] as List?)?.cast<String>() ?? const [],
        precautions: d['precautions'] as String?,
        rejectionReason: d['rejection_reason'] as String?,
        requestedAt: DateTime.tryParse((d['requested_at'] as String?) ?? '') ?? DateTime.now(),
      );

  String get operationTypesLabel =>
      operationTypes.isEmpty ? '—' : operationTypes.map((t) => kOperationTypeLabels[t] ?? t).join('، ');
}

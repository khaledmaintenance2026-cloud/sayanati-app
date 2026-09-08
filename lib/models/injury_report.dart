/// نموذج تقرير تحقيق إصابة عمل (QMS-SAF-007) — يطابق استمارة "تقرير تحقيق
/// بالحادث" الورقية بخطواتها الخمس بالضبط (راجع routes/injuryReports.js على
/// السيرفر لنفس القوائم والمفاتيح — يجب أن تبقى مطابقة حرفيًا بين الطرفين).

/// رأس الاستمارة: طبيعة الحادث (اختيار متعدد).
const Map<String, String> kNatureOfAccidentLabels = {
  'near_miss': 'خطر كامن وشيك الحدوث',
  'injury_illness': 'إصابة / مرض',
  'fire': 'حريق',
  'leakage': 'تسريب',
  'property_damage': 'ضرر في الممتلكات',
  'vehicle_accident': 'حادث سيارة',
  'explosion': 'انفجار',
};

/// رأس الاستمارة: نوع الإصابة/المرض على مستوى الحادث ككل (اختيار متعدد).
const Map<String, String> kInjuryTypeLabels = {
  'medical_treatment': 'إصابة/مرض (نقل إلى المستشفى)',
  'first_aid': 'إصابة/مرض (إسعافات أولية)',
  'lost_time': 'إصابة/مرض (وقت إجازة)',
  'fatality': 'وفاة',
};

/// الخطوة الثانية: أي جزء من دوام الموظف حدث فيه الحادث.
const Map<String, String> kWorkdayPartLabels = {
  'normal_activities': 'أثناء القيام بأعمال اعتيادية',
  'entering_leaving': 'أثناء الدخول أو الخروج',
  'meal_period': 'أثناء فترة تناول الطعام',
  'break': 'أثناء وقت الاستراحة',
  'overtime': 'أثناء العمل الإضافي',
  'other': 'أخرى',
};

/// الخطوة الثانية: معدات الحماية الشخصية المستخدمة أثناء الحادث — قائمة
/// مستقلة عن kPpeOptions في safety_permit.dart (تلك لتصاريح العمل، وهذه
/// لتحقيق الإصابات، رغم تشابه بعض العناصر).
const Map<String, String> kInjuryPpeLabels = {
  'helmet': 'خوذة السلامة',
  'safety_shoes': 'حذاء السلامة',
  'earplugs': 'سدادات الأذن',
  'earmuffs': 'غطاء الأذن',
  'glasses': 'نظارات',
  'face_protection': 'واقي الوجه',
  'gloves': 'قفازات',
  'dust_mask': 'قناع الغبار',
  'full_body_harness': 'حزام الجسم الكامل',
};

/// الخطوة الرابعة: هرم الضوابط (اختيار واحد).
const Map<String, String> kHierarchyOfControlLabels = {
  'elimination': 'إزالة الخطر',
  'substitution': 'الإحلال (الاستبدال)',
  'engineering_control': 'الضوابط الهندسية',
  'administrative_control': 'الضوابط الإدارية',
  'ppe': 'توفير معدات الحماية الشخصية',
};

/// الخطوة الرابعة: التغييرات المطلوبة لمنع تكرار الحادث (اختيار متعدد).
const Map<String, String> kPreventionChangeLabels = {
  'stop_activity': 'إيقاف هذا النشاط',
  'guard_hazard': 'حراسة الخطر',
  'train_employees': 'تدريب الموظفين',
  'train_supervisors': 'تدريب المشرفين',
  'redesign_task': 'إعادة تصميم خطوات المهمة',
  'redesign_workstation': 'إعادة تصميم محطة العمل',
  'new_policy': 'كتابة سياسة/قانون جديد',
  'enforce_policy': 'فرض السياسة القائمة',
  'routine_inspection': 'التفتيش الدوري عن المخاطر',
  'use_ppe': 'استخدام معدات الحماية الشخصية',
  'other': 'أخرى',
};

/// الخطوة الأولى: الجزء المتضرر في جسم الموظف المصاب (اختيار متعدد) — بديل
/// نصي لتظليل مخطط الجسم في الاستمارة الورقية.
const Map<String, String> kBodyPartLabels = {
  'head': 'الرأس',
  'face': 'الوجه',
  'eye': 'العين',
  'neck': 'الرقبة',
  'shoulder': 'الكتف',
  'arm': 'الذراع',
  'elbow': 'المرفق',
  'wrist': 'المعصم',
  'hand_fingers': 'اليد / الأصابع',
  'chest': 'الصدر',
  'back': 'الظهر',
  'abdomen': 'البطن',
  'pelvis': 'الحوض',
  'thigh': 'الفخذ',
  'knee': 'الركبة',
  'leg': 'الساق',
  'ankle': 'الكاحل',
  'foot_toes': 'القدم / أصابع القدم',
  'other': 'أخرى',
};

/// الخطوة الأولى: نوع عقد عمل الموظف المصاب (اختيار واحد).
const Map<String, String> kEmploymentTypeLabels = {
  'full_time': 'منتظم بدوام كامل',
  'part_time': 'منتظم بدوام جزئي',
  'seasonal': 'بدوام فصلي',
  'temporary': 'مؤقت',
  'contractor': 'متعاقد',
};

/// الخطوة الأولى: طبيعة الإصابة الأكثر شدة (اختيار متعدد).
const Map<String, String> kInjuryNatureLabels = {
  'abrasion': 'خدوش',
  'amputation': 'بتر',
  'broken_bone': 'كسر بالعظم',
  'bruise': 'رضوض وكدمات',
  'burn_heat': 'حروق بالحرارة',
  'burn_chemical': 'حروق بمواد كيميائية',
  'burn_fire': 'حروق بالنار',
  'concussion': 'ارتجاج بالرأس',
  'cut_laceration_puncture': 'قطع / تمزق / ثقب',
  'hernia': 'فتق',
  'sprain': 'التواء',
  'body_system_damage': 'أضرار بأنظمة الجسم',
  'other': 'أخرى',
};

String _label(Map<String, String> map, String key) => map[key] ?? key;

String multiLabel(Map<String, String> map, List<String> keys) =>
    keys.isEmpty ? '—' : keys.map((k) => _label(map, k)).join('، ');

enum InjuryReportStatus { open, closed }

InjuryReportStatus _statusFromApi(String? s) => s == 'closed' ? InjuryReportStatus.closed : InjuryReportStatus.open;

class InjuryReportEmployee {
  final String? id;
  final String employeeName;
  final String? nationality;
  final String? employeeIdNo;
  final int? age;
  final String? department;
  final String? jobTitle;
  final String? shift;
  final List<String> bodyPartsAffected;
  final int lostWorkDays;
  final String? employmentType;
  final int? monthsInJob;
  final int? monthsInCompany;
  final List<String> injuryNature;
  final String? injuryNatureOther;
  final bool isFatality;

  InjuryReportEmployee({
    this.id,
    required this.employeeName,
    this.nationality,
    this.employeeIdNo,
    this.age,
    this.department,
    this.jobTitle,
    this.shift,
    this.bodyPartsAffected = const [],
    this.lostWorkDays = 0,
    this.employmentType,
    this.monthsInJob,
    this.monthsInCompany,
    this.injuryNature = const [],
    this.injuryNatureOther,
    this.isFatality = false,
  });

  factory InjuryReportEmployee.fromApi(Map<String, dynamic> d) => InjuryReportEmployee(
        id: d['id']?.toString(),
        employeeName: (d['employee_name'] as String?) ?? '',
        nationality: d['nationality'] as String?,
        employeeIdNo: d['employee_id_no'] as String?,
        age: (d['age'] as num?)?.toInt(),
        department: d['department'] as String?,
        jobTitle: d['job_title'] as String?,
        shift: d['shift'] as String?,
        bodyPartsAffected: (d['body_parts_affected'] as List?)?.cast<String>() ?? const [],
        lostWorkDays: (d['lost_work_days'] as num?)?.toInt() ?? 0,
        employmentType: d['employment_type'] as String?,
        monthsInJob: (d['months_in_job'] as num?)?.toInt(),
        monthsInCompany: (d['months_in_company'] as num?)?.toInt(),
        injuryNature: (d['injury_nature'] as List?)?.cast<String>() ?? const [],
        injuryNatureOther: d['injury_nature_other'] as String?,
        isFatality: d['is_fatality'] == true,
      );

  Map<String, dynamic> toJson() => {
        'employeeName': employeeName,
        if (nationality != null) 'nationality': nationality,
        if (employeeIdNo != null) 'employeeIdNo': employeeIdNo,
        if (age != null) 'age': age,
        if (department != null) 'department': department,
        if (jobTitle != null) 'jobTitle': jobTitle,
        if (shift != null) 'shift': shift,
        'bodyPartsAffected': bodyPartsAffected,
        'lostWorkDays': lostWorkDays,
        if (employmentType != null) 'employmentType': employmentType,
        if (monthsInJob != null) 'monthsInJob': monthsInJob,
        if (monthsInCompany != null) 'monthsInCompany': monthsInCompany,
        'injuryNature': injuryNature,
        if (injuryNatureOther != null) 'injuryNatureOther': injuryNatureOther,
        'isFatality': isFatality,
      };
}

class InjuryReportAction {
  final String? id;
  final String actionDescription;
  final String? responsiblePerson;
  final DateTime? targetDate;
  final bool done;
  final DateTime? completedAt;

  InjuryReportAction({
    this.id,
    required this.actionDescription,
    this.responsiblePerson,
    this.targetDate,
    this.done = false,
    this.completedAt,
  });

  factory InjuryReportAction.fromApi(Map<String, dynamic> d) => InjuryReportAction(
        id: d['id']?.toString(),
        actionDescription: (d['action_description'] as String?) ?? '',
        responsiblePerson: d['responsible_person'] as String?,
        targetDate: d['target_date'] != null ? DateTime.tryParse(d['target_date'] as String) : null,
        done: d['status'] == 'done',
        completedAt: d['completed_at'] != null ? DateTime.tryParse(d['completed_at'] as String) : null,
      );

  /// يُرسل حالة "تم" الحالية مع كل تعديل كامل للتقرير (PATCH /:id) — السيرفر
  /// يحذف كل الإجراءات القديمة ويعيد إدراجها من هذه القائمة بالضبط، فبدون
  /// إرسال done هنا كانت أي إجراءات أُنجزت مسبقًا تُفقد حالتها عند أي تعديل
  /// آخر في التقرير (راجع routes/injuryReports.js، insertChildren).
  Map<String, dynamic> toJson() => {
        'actionDescription': actionDescription,
        if (responsiblePerson != null) 'responsiblePerson': responsiblePerson,
        if (targetDate != null) 'targetDate': targetDate!.toIso8601String().substring(0, 10),
        'done': done,
        if (completedAt != null) 'completedAt': completedAt!.toIso8601String(),
      };
}

class InjuryReportInvestigator {
  final String? id;
  final String name;
  final String? jobTitle;

  InjuryReportInvestigator({this.id, required this.name, this.jobTitle});

  factory InjuryReportInvestigator.fromApi(Map<String, dynamic> d) => InjuryReportInvestigator(
        id: d['id']?.toString(),
        name: (d['name'] as String?) ?? '',
        jobTitle: d['job_title'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (jobTitle != null) 'jobTitle': jobTitle,
      };
}

class InjuryReport {
  final String id;
  final String? incidentNumber;
  final String department;
  final DateTime investigationDate;

  final List<String> natureOfAccident;
  final List<String> injuryTypes;

  final String incidentLocation;
  final DateTime occurredAt;
  final String? workdayPart;
  final String? workdayPartOther;
  final bool witnessStatements;
  final bool photographsTaken;
  final bool mapsDrawings;
  final List<String> ppeUsed;
  final String incidentDescription;

  final String? unsafeConditionReason;
  final String? unsafeActReason;
  final bool? hadRewardIncentive;
  final bool? reportedBefore;
  final bool? similarIncidentsBefore;

  final String? hierarchyOfControl;
  final String? controlDetails;
  final List<String> preventionChanges;
  final String? preventionChangesOther;
  final String? preventionNotes;

  final String? writtenBy;
  final String? writtenByTitle;
  final String? approvedBy;
  final String? approvedByTitle;
  final DateTime? approvedAt;

  final InjuryReportStatus status;
  final String reportedBy;
  final DateTime createdAt;

  final List<InjuryReportEmployee> employees;
  final List<InjuryReportAction> actions;
  final List<InjuryReportInvestigator> investigators;

  InjuryReport({
    required this.id,
    this.incidentNumber,
    required this.department,
    required this.investigationDate,
    this.natureOfAccident = const [],
    this.injuryTypes = const [],
    required this.incidentLocation,
    required this.occurredAt,
    this.workdayPart,
    this.workdayPartOther,
    this.witnessStatements = false,
    this.photographsTaken = false,
    this.mapsDrawings = false,
    this.ppeUsed = const [],
    required this.incidentDescription,
    this.unsafeConditionReason,
    this.unsafeActReason,
    this.hadRewardIncentive,
    this.reportedBefore,
    this.similarIncidentsBefore,
    this.hierarchyOfControl,
    this.controlDetails,
    this.preventionChanges = const [],
    this.preventionChangesOther,
    this.preventionNotes,
    this.writtenBy,
    this.writtenByTitle,
    this.approvedBy,
    this.approvedByTitle,
    this.approvedAt,
    this.status = InjuryReportStatus.open,
    required this.reportedBy,
    required this.createdAt,
    this.employees = const [],
    this.actions = const [],
    this.investigators = const [],
  });

  bool get isClosed => status == InjuryReportStatus.closed;
  int get injuredCount => employees.length;
  int get fatalitiesCount => employees.where((e) => e.isFatality).length;

  factory InjuryReport.fromApi(Map<String, dynamic> d) => InjuryReport(
        id: d['id'].toString(),
        incidentNumber: d['incident_number'] as String?,
        department: (d['department'] as String?) ?? '',
        investigationDate: DateTime.tryParse((d['investigation_date'] as String?) ?? '') ?? DateTime.now(),
        natureOfAccident: (d['nature_of_accident'] as List?)?.cast<String>() ?? const [],
        injuryTypes: (d['injury_types'] as List?)?.cast<String>() ?? const [],
        incidentLocation: (d['incident_location'] as String?) ?? '',
        occurredAt: DateTime.tryParse((d['occurred_at'] as String?) ?? '') ?? DateTime.now(),
        workdayPart: d['workday_part'] as String?,
        workdayPartOther: d['workday_part_other'] as String?,
        witnessStatements: d['witness_statements'] == true,
        photographsTaken: d['photographs_taken'] == true,
        mapsDrawings: d['maps_drawings'] == true,
        ppeUsed: (d['ppe_used'] as List?)?.cast<String>() ?? const [],
        incidentDescription: (d['incident_description'] as String?) ?? '',
        unsafeConditionReason: d['unsafe_condition_reason'] as String?,
        unsafeActReason: d['unsafe_act_reason'] as String?,
        hadRewardIncentive: d['had_reward_incentive'] as bool?,
        reportedBefore: d['reported_before'] as bool?,
        similarIncidentsBefore: d['similar_incidents_before'] as bool?,
        hierarchyOfControl: d['hierarchy_of_control'] as String?,
        controlDetails: d['control_details'] as String?,
        preventionChanges: (d['prevention_changes'] as List?)?.cast<String>() ?? const [],
        preventionChangesOther: d['prevention_changes_other'] as String?,
        preventionNotes: d['prevention_notes'] as String?,
        writtenBy: d['written_by'] as String?,
        writtenByTitle: d['written_by_title'] as String?,
        approvedBy: d['approved_by'] as String?,
        approvedByTitle: d['approved_by_title'] as String?,
        approvedAt: d['approved_at'] != null ? DateTime.tryParse(d['approved_at'] as String) : null,
        status: _statusFromApi(d['status'] as String?),
        reportedBy: (d['reported_by'] as String?) ?? '',
        createdAt: DateTime.tryParse((d['created_at'] as String?) ?? '') ?? DateTime.now(),
        employees: (d['employees'] as List?)?.map((e) => InjuryReportEmployee.fromApi(e as Map<String, dynamic>)).toList() ?? const [],
        actions: (d['actions'] as List?)?.map((e) => InjuryReportAction.fromApi(e as Map<String, dynamic>)).toList() ?? const [],
        investigators:
            (d['investigators'] as List?)?.map((e) => InjuryReportInvestigator.fromApi(e as Map<String, dynamic>)).toList() ?? const [],
      );

  /// يبني حمولة POST/PATCH الكاملة (كل الخطوات الخمس دفعة واحدة) — راجع
  /// routes/injuryReports.js لنفس أسماء الحقول بالضبط.
  Map<String, dynamic> toJson() => {
        if (incidentNumber != null) 'incidentNumber': incidentNumber,
        'department': department,
        'investigationDate': investigationDate.toIso8601String().substring(0, 10),
        'natureOfAccident': natureOfAccident,
        'injuryTypes': injuryTypes,
        'incidentLocation': incidentLocation,
        'occurredAt': occurredAt.toIso8601String(),
        if (workdayPart != null) 'workdayPart': workdayPart,
        if (workdayPartOther != null) 'workdayPartOther': workdayPartOther,
        'witnessStatements': witnessStatements,
        'photographsTaken': photographsTaken,
        'mapsDrawings': mapsDrawings,
        'ppeUsed': ppeUsed,
        'incidentDescription': incidentDescription,
        if (unsafeConditionReason != null) 'unsafeConditionReason': unsafeConditionReason,
        if (unsafeActReason != null) 'unsafeActReason': unsafeActReason,
        if (hadRewardIncentive != null) 'hadRewardIncentive': hadRewardIncentive,
        if (reportedBefore != null) 'reportedBefore': reportedBefore,
        if (similarIncidentsBefore != null) 'similarIncidentsBefore': similarIncidentsBefore,
        if (hierarchyOfControl != null) 'hierarchyOfControl': hierarchyOfControl,
        if (controlDetails != null) 'controlDetails': controlDetails,
        'preventionChanges': preventionChanges,
        if (preventionChangesOther != null) 'preventionChangesOther': preventionChangesOther,
        if (preventionNotes != null) 'preventionNotes': preventionNotes,
        if (writtenBy != null) 'writtenBy': writtenBy,
        if (writtenByTitle != null) 'writtenByTitle': writtenByTitle,
        'employees': employees.map((e) => e.toJson()).toList(),
        'actions': actions.map((a) => a.toJson()).toList(),
        'investigators': investigators.map((i) => i.toJson()).toList(),
      };
}

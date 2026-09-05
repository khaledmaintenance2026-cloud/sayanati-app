import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/maintenance_report.dart';
import '../models/production.dart';
import '../models/safety_permit.dart';
import '../models/technician.dart';
import 'api_client.dart';

/// طبقة الحالة/البيانات لكل التطبيق.
///
/// ⚠️ حالة كل قسم مختلفة الآن بعد الانتقال لسيرفر صيانتي المحلي:
/// - الفنيون (technicians) وخطوط الإنتاج (productionLines) مربوطون فعليًا
///   بالسيرفر (Node.js + PostgreSQL) عبر [ApiClient] — كل عملية هنا تُخزَّن
///   فعليًا وتظهر لكل المستخدمين (لا حاجة لأي إشعار فوري إضافي، البيانات
///   تُحمَّل من جديد عند فتح/تحديث الشاشة).
/// - بلاغات الصيانة/الباتشات/تصاريح السلامة ما زالت بذاكرة محلية مؤقتة
///   (Mock) — لم تُهاجَر بعد. عند ربطها اتبعوا نفس نمط الفنيين/الإنتاج
///   أعلاه: تحميل (load...FromCloud) + إضافة/تعديل/حذف (...Cloud) تتصل
///   بمسارات REST الموجودة فعليًا على السيرفر (مثال: POST /safety-permits).
class AppState extends ChangeNotifier {
  final _uuid = const Uuid();
  final ApiClient _api = ApiClient.instance;

  // ---------------------------------------------------------------------
  // سجل نشاط مبسّط يحاكي الإشعارات الفورية + رسائل واتساب الجماعية،
  // لإظهار أن منطق سير العمل يعمل فعليًا (وليس مجرد تصميم ثابت). ملاحظة:
  // سيرفر صيانتي المحلي يملك بالفعل نظام Webhooks حقيقي (راجع تبويب
  // "إعدادات الموقع" في لوحة التحكم على السيرفر) يمكن ربطه بواتساب فعليًا
  // بدل هذا السجل الوهمي — راجع قسم التوصيات في تقرير المراجعة.
  // ---------------------------------------------------------------------
  final List<String> activityLog = [];

  void _log(String message) {
    activityLog.insert(0, message);
    if (activityLog.length > 50) activityLog.removeLast();
  }

  // ---------------------------------------------------------------------
  // الصيانة — الفنيون (مربوطون بالسيرفر المحلي فعليًا)
  // ---------------------------------------------------------------------
  final List<Technician> technicians = [];

  bool _attached = false;
  bool techniciansLoaded = false;
  String? techniciansError;

  /// تُستدعى مرة واحدة فور تسجيل الدخول بنجاح (راجع main.dart) — لا تحتاج
  /// أي رمز دخول يُمرَّر لها الآن؛ ApiClient يحمل رمز الجلسة الحالي داخليًا
  /// فور أن يستدعي AuthService.signIn/signUp عليه setToken.
  void attachAuth() {
    _attached = true;
    _loadTechniciansFromCloud();
    _loadProductionLinesFromCloud();
    _loadIncidentsFromCloud();
  }

  void detachAuth() {
    _attached = false;
    techniciansLoaded = false;
    technicians.clear();
    productionLinesLoaded = false;
    productionLines.clear();
    incidentsLoaded = false;
    incidents.clear();
  }

  Future<void> reloadTechnicians() => _loadTechniciansFromCloud();

  Future<void> _loadTechniciansFromCloud() async {
    if (!_attached) return;
    try {
      final data = await _api.get('/technicians');
      final list = (data['technicians'] as List).cast<Map<String, dynamic>>();
      technicians
        ..clear()
        ..addAll(list.map(Technician.fromApi));
      techniciansLoaded = true;
      techniciansError = null;
      notifyListeners();
    } catch (e) {
      // نُبقي القائمة كما كانت (فارغة أو من تحميل سابق ناجح)، وتُعرض رسالة
      // الخطأ في لوحة الإدارة مع زر لإعادة المحاولة (reloadTechnicians).
      techniciansError = 'تعذّر تحميل الفنيين من السيرفر: $e';
      notifyListeners();
    }
  }

  Future<void> addTechnicianCloud({
    required String name,
    required String specialty,
    String? phone,
  }) async {
    final data = await _api.post('/technicians', {
      'name': name,
      'specialty': specialty,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });
    technicians.add(Technician.fromApi(data['technician'] as Map<String, dynamic>));
    notifyListeners();
  }

  Future<void> updateTechnicianCloud(
    String id, {
    String? name,
    String? specialty,
    String? phone,
    bool? available,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (specialty != null) body['specialty'] = specialty;
    if (phone != null) body['phone'] = phone;
    if (available != null) body['status'] = available ? 'available' : 'busy';
    if (body.isEmpty) return;

    final data = await _api.patch('/technicians/$id', body);
    final updated = Technician.fromApi(data['technician'] as Map<String, dynamic>);
    final i = technicians.indexWhere((t) => t.id == id);
    if (i != -1) technicians[i] = updated;
    notifyListeners();
  }

  Future<void> removeTechnicianCloud(String id) async {
    await _api.delete('/technicians/$id');
    technicians.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // الصيانة — البلاغات وأوامر العمل (لا تزال محلية Mock — راجع الملاحظة
  // أعلى الملف وتقرير المراجعة لخطة ربطها بمسارات /production/incidents
  // و /work-orders و /loto على السيرفر المحلي)
  // ---------------------------------------------------------------------
  final List<MaintenanceReport> maintenanceReports = [];

  void seedMaintenance() {
    final now = DateTime.now();
    maintenanceReports.addAll([
      MaintenanceReport(
        id: _uuid.v4(),
        equipment: 'ماكينة الخلط',
        line: 'خط ٩',
        description: 'توقف مفاجئ — صوت غير طبيعي بالمحرك، وتوقف كامل لخط الإنتاج.',
        kind: MaintenanceKind.emergency,
        status: MaintenanceStatus.pendingAssignment,
        reportedBy: 'محمد — الإنتاج',
        reportedAt: now.subtract(const Duration(minutes: 8)),
      ),
      MaintenanceReport(
        id: _uuid.v4(),
        equipment: 'سير النقل',
        line: 'خط ٧',
        description: 'اهتزاز غير طبيعي في السير الرئيسي.',
        kind: MaintenanceKind.emergency,
        status: MaintenanceStatus.inProgress,
        reportedBy: 'خالد — الإنتاج',
        reportedAt: now.subtract(const Duration(minutes: 25)),
        assignedTechnicianIds: ['t1'],
        assignedAt: now.subtract(const Duration(minutes: 20)),
      ),
      MaintenanceReport(
        id: _uuid.v4(),
        equipment: 'مضخة تبريد',
        line: 'خط ١١',
        description: 'استبدال حلقة إحكام مسربة.',
        kind: MaintenanceKind.emergency,
        status: MaintenanceStatus.completed,
        reportedBy: 'أحمد — الإنتاج',
        reportedAt: now.subtract(const Duration(days: 1, minutes: 31)),
        assignedTechnicianIds: ['t3'],
        assignedAt: now.subtract(const Duration(days: 1, minutes: 28)),
        closedAt: now.subtract(const Duration(days: 1)),
        closeDescription: 'تم استبدال حلقة الإحكام وتشغيل المضخة والتأكد من عدم وجود تسريب.',
        partsUsed: 'حلقة إحكام مقاس ٤٠مم × ١',
      ),
    ]);
  }

  List<MaintenanceReport> get openEmergencyReports => maintenanceReports
      .where((r) => r.isEmergency && r.status != MaintenanceStatus.completed)
      .toList();

  MaintenanceReport createReport({
    required String equipment,
    required String line,
    required String description,
    required String reportedBy,
  }) {
    final report = MaintenanceReport(
      id: _uuid.v4(),
      equipment: equipment,
      line: line,
      description: description,
      kind: MaintenanceKind.emergency,
      reportedBy: reportedBy,
      reportedAt: DateTime.now(),
    );
    maintenanceReports.insert(0, report);
    _log('🔔 إشعار فوري + واتساب لجروب الصيانة: بلاغ جديد "$equipment — $line"');
    notifyListeners();
    return report;
  }

  MaintenanceReport createWorkOrder({
    required String line,
    required String description,
    required List<String> technicianIds,
    int? reminderIntervalDays,
  }) {
    final order = MaintenanceReport(
      id: _uuid.v4(),
      equipment: description,
      line: line,
      description: description,
      kind: MaintenanceKind.preventive,
      status: MaintenanceStatus.inProgress,
      reportedBy: 'مشرف الصيانة',
      reportedAt: DateTime.now(),
      assignedTechnicianIds: technicianIds,
      assignedAt: DateTime.now(),
      reminderIntervalDays: reminderIntervalDays,
    );
    maintenanceReports.insert(0, order);
    _log('🔔 واتساب لجروب الصيانة: أمر عمل وقائي جديد — $line');
    notifyListeners();
    return order;
  }

  void assignTechnician(String reportId, String technicianId) {
    final report = maintenanceReports.firstWhere((r) => r.id == reportId);
    report.assignedTechnicianIds = [technicianId];
    report.assignedAt = DateTime.now();
    report.status = MaintenanceStatus.inProgress;
    final tech = technicians.firstWhere((t) => t.id == technicianId);
    // تصحيح لعلّة كانت موجودة في نسخة Firebase: حالة "متاح/مشغول" للفني لم
    // تكن تتغيّر تلقائيًا عند التعيين — الآن تُحدَّث فعليًا على السيرفر (الفنيون
    // مربوطون به فعليًا)، حتى لو بقي البلاغ نفسه محليًا مؤقتًا. لا ننتظر
    // (await) النتيجة حتى تبقى هذه الدالة متزامنة كما تتوقعها الشاشات الحالية.
    tech.available = false;
    updateTechnicianCloud(technicianId, available: false).catchError((e) {
      techniciansError = 'تعذّر تحديث حالة الفني على السيرفر: $e';
      notifyListeners();
    });
    _log('🔔 واتساب لجروب الصيانة: تم إسناد بلاغ "${report.equipment}" للفني ${tech.name}');
    notifyListeners();
  }

  void closeReport(String reportId, {required String closeDescription, required String partsUsed}) {
    final report = maintenanceReports.firstWhere((r) => r.id == reportId);
    report.closeDescription = closeDescription;
    report.partsUsed = partsUsed;
    report.closedAt = DateTime.now();
    report.status = MaintenanceStatus.completed;
    // نفس تصحيح العلّة أعلاه: نُعيد الفني/الفنيين المعيّنين لحالة "متاح" فعليًا
    // على السيرفر عند إنجاز البلاغ، بدل تركهم "مشغولين" للأبد بالخطأ.
    for (final techId in report.assignedTechnicianIds) {
      final idx = technicians.indexWhere((t) => t.id == techId);
      if (idx == -1) continue;
      technicians[idx].available = true;
      updateTechnicianCloud(techId, available: true).catchError((e) {
        techniciansError = 'تعذّر تحديث حالة الفني على السيرفر: $e';
        notifyListeners();
      });
    }
    _log('🔔 إشعار لقسم الإنتاج + واتساب الصيانة: أُنجز بلاغ "${report.equipment}" '
        '(المدة: ${report.duration != null ? report.duration!.inMinutes : 0} دقيقة)');
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // الإنتاج — خطوط الإنتاج (مربوطة بالسيرفر المحلي فعليًا، بنفس نمط
  // الفنيين أعلاه). الباتشات نفسها لا تزال محلية Mock (راجع الملاحظة أعلى
  // الملف وتقرير المراجعة لخطة ربطها بمسار /production لاحقًا).
  // ---------------------------------------------------------------------
  final List<ProductionLine> productionLines = [];

  bool productionLinesLoaded = false;
  String? productionLinesError;

  Future<void> reloadProductionLines() => _loadProductionLinesFromCloud();

  Future<void> _loadProductionLinesFromCloud() async {
    if (!_attached) return;
    try {
      final data = await _api.get('/production/lines');
      final list = (data['lines'] as List).cast<Map<String, dynamic>>();
      productionLines
        ..clear()
        ..addAll(list.map(ProductionLine.fromApi));
      productionLinesLoaded = true;
      productionLinesError = null;
      notifyListeners();
    } catch (e) {
      productionLinesError = 'تعذّر تحميل خطوط الإنتاج من السيرفر: $e';
      notifyListeners();
    }
  }

  Future<void> addProductionLineCloud({required String name, String? location}) async {
    final data = await _api.post('/production/lines', {
      'name': name,
      if (location != null && location.isNotEmpty) 'location': location,
    });
    productionLines.add(ProductionLine.fromApi(data['line'] as Map<String, dynamic>));
    notifyListeners();
  }

  Future<void> updateProductionLineCloud(
    String id, {
    String? name,
    String? location,
    bool? active,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (location != null) body['location'] = location;
    if (active != null) body['active'] = active;
    if (body.isEmpty) return;

    final data = await _api.patch('/production/lines/$id', body);
    final updated = ProductionLine.fromApi(data['line'] as Map<String, dynamic>);
    final i = productionLines.indexWhere((l) => l.id == id);
    if (i != -1) productionLines[i] = updated;
    notifyListeners();
  }

  Future<void> removeProductionLineCloud(String id) async {
    await _api.delete('/production/lines/$id');
    productionLines.removeWhere((l) => l.id == id);
    notifyListeners();
  }

  /// خطوط الإنتاج التابعة لقسم/مصنع معيّن (مثال: 'مصنع الرجال') — أساس فصل
  /// "مصنع الرجال" عن "مصنع النساء" إداريًا في الواجهة، حسب عمود location
  /// الموجود فعليًا على كل خط (ومقيَّد بنفس القيم على السيرفر، راجع
  /// kFacilityLocations في services/constants.dart).
  List<ProductionLine> linesByFacility(String facility) =>
      productionLines.where((l) => l.location == facility).toList();

  final List<Batch> batches = [];

  Batch recordBatch({
    required String lineId,
    required String productName,
    required int quantity,
    required String recordedBy,
    bool hasStoppage = false,
    String? stoppageReason,
    int? stoppageMinutes,
    String? operationalNotes,
    String? actionsTaken,
  }) {
    final batch = Batch(
      id: _uuid.v4(),
      lineId: lineId,
      productName: productName,
      quantity: quantity,
      date: DateTime.now(),
      hasStoppage: hasStoppage,
      stoppageReason: stoppageReason,
      stoppageMinutes: stoppageMinutes,
      operationalNotes: operationalNotes,
      actionsTaken: actionsTaken,
      recordedBy: recordedBy,
    );
    batches.insert(0, batch);
    _log('🔔 واتساب لجروب الإنتاج اليومي: باتش جديد على ${lineById(lineId).name} — الكمية $quantity');
    notifyListeners();
    return batch;
  }

  ProductionLine lineById(String id) => productionLines.firstWhere((l) => l.id == id);

  /// كل الباتشات المسجّلة على خطوط قسم/مصنع معيّن اليوم.
  List<Batch> batchesByFacility(String facility) {
    final lineIds = linesByFacility(facility).map((l) => l.id).toSet();
    return batches.where((b) => lineIds.contains(b.lineId)).toList();
  }

  // ---------------------------------------------------------------------
  // الإنتاج — بلاغات أعطال فورية (مربوطة بالسيرفر المحلي فعليًا عبر
  // /production/incidents، بنفس نمط خطوط الإنتاج أعلاه).
  // ---------------------------------------------------------------------
  final List<Incident> incidents = [];
  bool incidentsLoaded = false;
  String? incidentsError;

  Future<void> reloadIncidents() => _loadIncidentsFromCloud();

  Future<void> _loadIncidentsFromCloud() async {
    if (!_attached) return;
    try {
      final data = await _api.get('/production/incidents');
      final list = (data['incidents'] as List).cast<Map<String, dynamic>>();
      incidents
        ..clear()
        ..addAll(list.map(Incident.fromApi));
      incidentsLoaded = true;
      incidentsError = null;
      notifyListeners();
    } catch (e) {
      incidentsError = 'تعذّر تحميل البلاغات من السيرفر: $e';
      notifyListeners();
    }
  }

  Future<void> addIncidentCloud({
    String? lineId,
    String? equipmentId,
    required String description,
  }) async {
    final data = await _api.post('/production/incidents', {
      if (lineId != null) 'lineId': lineId,
      if (equipmentId != null) 'equipmentId': equipmentId,
      'description': description,
    });
    incidents.insert(0, Incident.fromApi(data['incident'] as Map<String, dynamic>));
    _log('🔔 بلاغ عطل جديد في الإنتاج: $description');
    notifyListeners();
  }

  Future<void> endIncidentDowntimeCloud(String id) async {
    final data = await _api.patch('/production/incidents/$id/end-downtime', {});
    final updated = Incident.fromApi(data['incident'] as Map<String, dynamic>);
    final i = incidents.indexWhere((e) => e.id == id);
    if (i != -1) incidents[i] = updated;
    notifyListeners();
  }

  Future<void> removeIncidentCloud(String id) async {
    await _api.delete('/production/incidents/$id');
    incidents.removeWhere((e) => e.id == id);
    notifyListeners();
  }

  int lineTotalToday(String lineId) =>
      batches.where((b) => b.lineId == lineId).fold(0, (sum, b) => sum + b.quantity);

  // ---------------------------------------------------------------------
  // السلامة (لا يزال محليًا Mock — راجع POST /safety-permits و /loto و
  // /near-miss على السيرفر المحلي)
  // ---------------------------------------------------------------------
  final List<SafetyPermit> permits = [];

  void seedSafety() {
    permits.add(SafetyPermit(
      id: _uuid.v4(),
      requesterName: 'عبدالله حسن',
      requesterRole: 'فني صيانة',
      location: 'خط ٩ — ماكينة الخلط',
      description: 'أعمال لحام لإصلاح تسريب في خط الأنابيب.',
      techniciansCount: 2,
      requestedBy: 'عبدالله حسن',
      requestedAt: DateTime.now().subtract(const Duration(minutes: 12)),
    ));
  }

  SafetyPermit requestPermit({
    required String requesterName,
    required String requesterRole,
    required String location,
    required String description,
    required int techniciansCount,
    String? relatedReportId,
  }) {
    final permit = SafetyPermit(
      id: _uuid.v4(),
      requesterName: requesterName,
      requesterRole: requesterRole,
      location: location,
      description: description,
      techniciansCount: techniciansCount,
      relatedReportId: relatedReportId,
      requestedBy: requesterName,
      requestedAt: DateTime.now(),
    );
    permits.insert(0, permit);
    _log('🔔 إشعار لقسم السلامة: طلب تصريح عمل جديد — $location');
    notifyListeners();
    return permit;
  }

  void reviewPermit(String permitId, {required bool approve, required String reviewer}) {
    final permit = permits.firstWhere((p) => p.id == permitId);
    permit.status = approve ? PermitStatus.approved : PermitStatus.rejected;
    permit.reviewedBy = reviewer;
    permit.reviewedAt = DateTime.now();
    _log('🔔 إشعار لمقدّم الطلب: تصريح "${permit.location}" ${approve ? 'تمت الموافقة عليه' : 'رُفض'}');
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  void seedAll() {
    seedMaintenance();
    seedSafety();
  }

  @override
  void dispose() {
    detachAuth();
    super.dispose();
  }
}

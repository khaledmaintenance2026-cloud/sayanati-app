import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/maintenance_report.dart';
import '../models/production.dart';
import '../models/safety_permit.dart';
import '../models/technician.dart';

/// طبقة الحالة/البيانات لكل التطبيق.
///
/// هذا التطبيق يعمل الآن بذاكرة محلية (Mock) حتى يعمل ويُختبر فورًا بلا خادم.
/// عندما يتوفر مشروع Firebase الخاص بكم، يُستبدل محتوى هذا الملف بمزوّد
/// يقرأ/يكتب من Cloud Firestore ويرسل إشعارات عبر Firebase Cloud Messaging،
/// دون الحاجة لتغيير أي شاشة — كل الشاشات تتحدث فقط مع AppState عبر Provider.
class AppState extends ChangeNotifier {
  final _uuid = const Uuid();

  // ---------------------------------------------------------------------
  // سجل نشاط مبسّط يحاكي الإشعارات الفورية + رسائل واتساب الجماعية،
  // لإظهار أن منطق سير العمل يعمل فعليًا (وليس مجرد تصميم ثابت).
  // ---------------------------------------------------------------------
  final List<String> activityLog = [];

  void _log(String message) {
    activityLog.insert(0, message);
    if (activityLog.length > 50) activityLog.removeLast();
  }

  // ---------------------------------------------------------------------
  // الصيانة
  // ---------------------------------------------------------------------
  final List<Technician> technicians = [
    Technician(id: 't1', name: 'عبدالله حسن', specialty: 'كهرباء وميكانيكا', available: true),
    Technician(id: 't2', name: 'سالم مبارك', specialty: 'تبريد وتكييف', available: false),
    Technician(id: 't3', name: 'يوسف طارق', specialty: 'ميكانيكا عامة', available: true),
  ];

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
    _log('🔔 واتساب لجروب الصيانة: تم إسناد بلاغ "${report.equipment}" للفني ${tech.name}');
    notifyListeners();
  }

  void closeReport(String reportId, {required String closeDescription, required String partsUsed}) {
    final report = maintenanceReports.firstWhere((r) => r.id == reportId);
    report.closeDescription = closeDescription;
    report.partsUsed = partsUsed;
    report.closedAt = DateTime.now();
    report.status = MaintenanceStatus.completed;
    _log('🔔 إشعار لقسم الإنتاج + واتساب الصيانة: أُنجز بلاغ "${report.equipment}" '
        '(المدة: ${report.duration != null ? report.duration!.inMinutes : 0} دقيقة)');
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // الإنتاج
  // ---------------------------------------------------------------------
  final List<ProductionLine> productionLines = List.generate(
    6,
    (i) => ProductionLine(id: 'line${i + 7}', name: 'خط ${_easternInt(i + 7)}'),
  );

  final List<Batch> batches = [];

  static String _easternInt(int n) {
    const d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return n.toString().split('').map((c) => d[int.parse(c)]).join();
  }

  void seedProduction() {
    final now = DateTime.now();
    batches.addAll([
      Batch(id: _uuid.v4(), lineId: 'line7', productName: 'حديد تسليح ١٢ مم', quantity: 310, date: now, recordedBy: 'مشرف الخط ٧'),
      Batch(id: _uuid.v4(), lineId: 'line8', productName: 'حديد تسليح ١٠ مم', quantity: 330, date: now, recordedBy: 'مشرف الخط ٨'),
      Batch(id: _uuid.v4(), lineId: 'line9', productName: 'حديد تسليح ١٦ مم', quantity: 300, date: now,
          hasStoppage: true, stoppageReason: 'عطل ميكانيكي مفاجئ', stoppageMinutes: 65, recordedBy: 'مشرف الخط ٩'),
    ]);
  }

  Batch recordBatch({
    required String lineId,
    required String productName,
    required int quantity,
    required String recordedBy,
    bool hasStoppage = false,
    String? stoppageReason,
    int? stoppageMinutes,
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
      recordedBy: recordedBy,
    );
    batches.insert(0, batch);
    _log('🔔 واتساب لجروب الإنتاج اليومي: باتش جديد على ${lineById(lineId).name} — الكمية $quantity');
    notifyListeners();
    return batch;
  }

  ProductionLine lineById(String id) => productionLines.firstWhere((l) => l.id == id);

  int lineTotalToday(String lineId) =>
      batches.where((b) => b.lineId == lineId).fold(0, (sum, b) => sum + b.quantity);

  // ---------------------------------------------------------------------
  // السلامة
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
    seedProduction();
    seedSafety();
  }
}

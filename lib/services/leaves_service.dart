import '../models/leaves.dart';
import 'api_client.dart';
import 'constants.dart';

/// طلبات «إجازات الموظفين» (مصنع الرجال) إلى سيرفر صيانتي (/api/leaves).
/// كل الحسابات (الرصيد، المدفوع، بدون راتب، الحالة، التنبيهات) تتم في السيرفر؛
/// هذه الدوال ترسل التواريخ فقط وتعيد النتيجة المحسوبة. كل الدوال ترمي [ApiException]
/// برسالة عربية جاهزة للعرض عند أي خطأ (مثل التداخل أو تاريخ غير موجود).
class LeavesService {
  LeavesService._();

  static final ApiClient _api = ApiClient.instance;

  static Map<String, dynamic> _map(dynamic data) =>
      data is Map<String, dynamic> ? data : <String, dynamic>{};

  static LeaveEmployee _employeeOf(dynamic data) {
    final m = _map(data);
    return LeaveEmployee.fromApi(_map(m['employee']));
  }

  // ------------------------------- الملخص والإعدادات -------------------------------

  static Future<LeaveSummary> fetchSummary() async {
    final data = await _api.get('/leaves/summary');
    return LeaveSummary.fromApi(_map(data));
  }

  static Future<LeaveSettings> fetchSettings() async {
    final data = await _api.get('/leaves/settings');
    return LeaveSettings.fromApi(_map(_map(data)['settings']));
  }

  /// لمدير النظام فقط (السيرفر يرفض غيره).
  static Future<LeaveSettings> saveSettings({
    required double annualDays,
    required int expiryYears,
    required String paidRounding,
    required int soonDays,
    required bool alertsEnabled,
  }) async {
    final data = await _api.put('/leaves/settings', {
      'annualDays': annualDays,
      'expiryYears': expiryYears,
      'paidRounding': paidRounding,
      'soonDays': soonDays,
      'alertsEnabled': alertsEnabled,
    });
    return LeaveSettings.fromApi(_map(_map(data)['settings']));
  }

  // ------------------------------- الموظفون -------------------------------

  static Future<List<LeaveEmployee>> fetchEmployees() async {
    final data = await _api.get('/leaves/employees');
    final list = _map(data)['employees'];
    if (list is! List) return const [];
    return list.map((e) => LeaveEmployee.fromApi(e as Map<String, dynamic>)).toList();
  }

  static Future<LeaveEmployee> fetchEmployee(String id) async {
    final data = await _api.get('/leaves/employees/$id');
    return _employeeOf(data);
  }

  /// التواريخ نصوص 'YYYY-MM-DD' أو null (null/فارغ = غير مُدخل).
  static Future<LeaveEmployee> addEmployee({
    required String name,
    required String employeeNumber,
    String? department,
    String? hireDate,
    String? startDate,
  }) async {
    final data = await _api.post('/leaves/employees', {
      'name': name,
      'employeeNumber': employeeNumber,
      'department': department ?? '',
      'hireDate': hireDate ?? '',
      'startDate': startDate ?? '',
    });
    return _employeeOf(data);
  }

  static Future<LeaveEmployee> updateEmployee(
    String id, {
    required String name,
    required String employeeNumber,
    String? department,
    String? hireDate,
    String? startDate,
  }) async {
    final data = await _api.patch('/leaves/employees/$id', {
      'name': name,
      'employeeNumber': employeeNumber,
      'department': department ?? '',
      'hireDate': hireDate ?? '',
      'startDate': startDate ?? '',
    });
    return _employeeOf(data);
  }

  // ------------------------------- الإجازات -------------------------------

  /// معاينة قبل الحفظ: الرصيد عند البدء + المدفوع + بدون راتب (لا يحفظ شيئًا).
  static Future<LeavePreview> preview({
    required String employeeId,
    required String start,
    required String expected,
    String? actual,
    String? excludeLeaveId,
  }) async {
    final body = <String, dynamic>{
      'employeeId': employeeId,
      'start': start,
      'expected': expected,
    };
    if (actual != null) body['actual'] = actual;
    if (excludeLeaveId != null) body['excludeLeaveId'] = excludeLeaveId;
    final data = await _api.post('/leaves/preview', body);
    return LeavePreview.fromApi(_map(_map(data)['preview']));
  }

  static Future<LeaveEmployee> addLeave(
    String employeeId, {
    required String start,
    required String expected,
    String? note,
    String? replacement,
  }) async {
    final data = await _api.post('/leaves/employees/$employeeId/leaves', {
      'start': start,
      'expected': expected,
      'note': note ?? '',
      'replacement': replacement ?? '',
    });
    return _employeeOf(data);
  }

  /// تعديل إجازة: تواريخها وملاحظتها ([actual] = تاريخ المباشرة لو سُجّلت).
  static Future<LeaveEmployee> updateLeave(
    String leaveId, {
    required String start,
    required String expected,
    String? actual,
    String? note,
    String? replacement,
  }) async {
    final body = <String, dynamic>{
      'start': start,
      'expected': expected,
      'note': note ?? '',
      'replacement': replacement ?? '',
    };
    if (actual != null) body['actual'] = actual;
    final data = await _api.patch('/leaves/leaves/$leaveId', body);
    return _employeeOf(data);
  }

  /// «تسجيل المباشرة» بعد الإجازة.
  static Future<LeaveEmployee> registerReturn(String leaveId, String actualDate) async {
    final data = await _api.post('/leaves/leaves/$leaveId/return', {'actualDate': actualDate});
    return _employeeOf(data);
  }

  static Future<LeaveEmployee> deleteLeave(String leaveId) async {
    final data = await _api.delete('/leaves/leaves/$leaveId');
    return _employeeOf(data);
  }

  // ------------------------------- التقارير -------------------------------

  /// تقرير للعرض/الطباعة. بلا [employeeId] = تقرير شامل ([status] فلتر اختياري:
  /// active | on_leave | upcoming | late)، ومعه [employeeId] = كشف موظف واحد.
  static Future<LeaveReportData> fetchReport({String? employeeId, String? status}) async {
    final query = <String, dynamic>{};
    if (employeeId != null) query['employeeId'] = employeeId;
    if (status != null) query['status'] = status;
    final data = await _api.get('/leaves/report', query: query);
    return LeaveReportData.fromApi(_map(data));
  }

  /// رابط تنزيل ملف Excel (يُفتح في المتصفح الخارجي بنفس رمز الدخول، مثل تصدير المخزون).
  /// يرجع null لو لم يكن المستخدم مسجّلًا.
  static Uri? excelUri({String? employeeId, String? status}) {
    final token = _api.token;
    if (token == null) return null;
    final query = <String, String>{'token': token};
    if (employeeId != null) query['employeeId'] = employeeId;
    if (status != null) query['status'] = status;
    return Uri.parse('$kApiBaseUrl/leaves/export.xlsx').replace(queryParameters: query);
  }
}

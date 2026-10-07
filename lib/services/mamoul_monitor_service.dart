import '../models/mamoul_monitor.dart';
import 'api_client.dart';

/// طلبات "مراقبة مكينة المعمول" إلى سيرفر صيانتي (/api/mamoul-monitor).
/// الصلاحية على السيرفر نفسه: فريق الصيانة (فني/مسؤول صيانة/مسؤول المخزون/
/// المصمم) + مدير النظام + إنتاج مصنع النساء. كل الدوال ترمي [ApiException]
/// برسالة عربية جاهزة للعرض عند أي خطأ.
class MamoulMonitorService {
  MamoulMonitorService._();

  static final ApiClient _api = ApiClient.instance;
  static const String _base = '/mamoul-monitor';

  static Map<String, dynamic> _map(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  // ------------------------------- المكائن -------------------------------

  /// كل المكائن (المعطّلة أيضًا، بعلامة active).
  static Future<List<MamoulMachine>> fetchMachines() async {
    final data = await _api.get('$_base/machines');
    return MamoulMachine.listFromApi(data);
  }

  /// إضافة مكينة (مسؤول الصيانة / مدير النظام فقط).
  static Future<MamoulMachine> addMachine({required String name, String? code}) async {
    final data = await _api.post('$_base/machines', {'name': name, 'code': code});
    return MamoulMachine.fromApi(Map<String, dynamic>.from(_map(data)['machine'] as Map));
  }

  /// تعديل الاسم/الرمز/التفعيل. المرسَل فقط هو ما يتغيّر.
  static Future<MamoulMachine> updateMachine(String id, {String? name, String? code, bool? active}) async {
    final data = await _api.patch('$_base/machines/$id', {
      if (name != null) 'name': name,
      if (code != null) 'code': code,
      if (active != null) 'active': active,
    });
    return MamoulMachine.fromApi(Map<String, dynamic>.from(_map(data)['machine'] as Map));
  }

  /// حذف نهائي — يرفضه السيرفر لو للمكينة تشغيلات أو أعطال (عطّلها بدلًا من ذلك).
  static Future<void> deleteMachine(String id) async {
    await _api.delete('$_base/machines/$id');
  }

  // ------------------------------- التشغيلات -------------------------------

  /// تشغيلات يوم واحد مع إجمالياتها، ويمكن حصرها على [machineId].
  static Future<MamoulRunsResult> fetchRunsOfDay(String date, {String? machineId}) async {
    final query = <String, dynamic>{'date': date};
    if (machineId != null) query['machineId'] = machineId;
    final data = await _api.get('$_base/runs', query: query);
    return MamoulRunsResult.fromApi(data);
  }

  static Future<MamoulRunDetail> fetchRun(String id) async {
    final data = await _api.get('$_base/runs/$id');
    return MamoulRunDetail.fromApi(data);
  }

  static Future<MamoulRunDetail> createRun({
    required String machineId,
    required String runDate,
    required double targetWeight,
    String? shift,
    String? startTime,
    String? operatorName,
    String? pasteBatch,
    String? moistureLevel,
    double? moisturePct,
    required String speedUnit,
    double? speedBelt,
    double? speedPush,
    double? speedRotary,
    String? notes,
  }) async {
    final data = await _api.post('$_base/runs', {
      'machineId': machineId,
      'runDate': runDate,
      'targetWeight': targetWeight,
      'shift': shift,
      'startTime': startTime,
      'operatorName': operatorName,
      'pasteBatch': pasteBatch,
      'pasteMoistureLevel': moistureLevel,
      'pasteMoisturePct': moisturePct,
      'speedUnit': speedUnit,
      'speedBelt': speedBelt,
      'speedPush': speedPush,
      'speedRotary': speedRotary,
      'notes': notes,
    });
    return MamoulRunDetail.fromApi(data);
  }

  /// تعديل بيانات التشغيلة (ليس السرعات ولا الحالة). null = مسح الحقل.
  static Future<MamoulRunDetail> updateRun(
    String id, {
    required String machineId,
    required String runDate,
    required double targetWeight,
    String? shift,
    String? startTime,
    String? endTime,
    String? operatorName,
    String? pasteBatch,
    String? moistureLevel,
    double? moisturePct,
    required String speedUnit,
    int? producedCount,
    String? notes,
  }) async {
    final data = await _api.patch('$_base/runs/$id', {
      'machineId': machineId,
      'runDate': runDate,
      'targetWeight': targetWeight,
      'shift': shift,
      'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
      'operatorName': operatorName,
      'pasteBatch': pasteBatch,
      'pasteMoistureLevel': moistureLevel,
      'pasteMoisturePct': moisturePct,
      'speedUnit': speedUnit,
      'producedCount': producedCount,
      'notes': notes,
    });
    return MamoulRunDetail.fromApi(data);
  }

  static Future<MamoulRunDetail> closeRun(String id, {String? endTime, int? producedCount}) async {
    final data = await _api.post('$_base/runs/$id/close', {
      if (endTime != null) 'endTime': endTime,
      if (producedCount != null) 'producedCount': producedCount,
    });
    return MamoulRunDetail.fromApi(data);
  }

  static Future<MamoulRunDetail> reopenRun(String id) async {
    final data = await _api.post('$_base/runs/$id/reopen', <String, dynamic>{});
    return MamoulRunDetail.fromApi(data);
  }

  static Future<void> deleteRun(String id) async {
    await _api.delete('$_base/runs/$id');
  }

  // ------------------------------- السرعات -------------------------------

  static Future<MamoulRunDetail> changeSpeeds(
    String runId, {
    double? belt,
    double? push,
    double? rotary,
    String? reason,
  }) async {
    final data = await _api.post('$_base/runs/$runId/speeds', {
      'speedBelt': belt,
      'speedPush': push,
      'speedRotary': rotary,
      'reason': reason,
    });
    return MamoulRunDetail.fromApi(data);
  }

  // ------------------------------- العيّنات -------------------------------

  /// [piecesPerMin] قطع/دقيقة، [pressureLevel] ضغط اليد (none/light/medium/strong)،
  /// [doughTemp] حرارة العجينة °م — كلها اختيارية.
  static Future<MamoulSample> addSample(
    String runId, {
    required List<double> weights,
    String? note,
    double? piecesPerMin,
    String? pressureLevel,
    double? doughTemp,
  }) async {
    final data = await _api.post('$_base/runs/$runId/samples', {
      'weights': weights,
      'note': note,
      'piecesPerMin': piecesPerMin,
      'pressureLevel': pressureLevel,
      'doughTemp': doughTemp,
    });
    return MamoulSample.fromApi(Map<String, dynamic>.from(_map(data)['sample'] as Map));
  }

  /// كل الحقول تُرسَل (null في قطع/ضغط/حرارة = مسح القيمة).
  static Future<MamoulSample> updateSample(
    String id, {
    required List<double> weights,
    String? note,
    double? piecesPerMin,
    String? pressureLevel,
    double? doughTemp,
  }) async {
    final data = await _api.patch('$_base/samples/$id', {
      'weights': weights,
      'note': note ?? '',
      'piecesPerMin': piecesPerMin,
      'pressureLevel': pressureLevel,
      'doughTemp': doughTemp,
    });
    return MamoulSample.fromApi(Map<String, dynamic>.from(_map(data)['sample'] as Map));
  }

  static Future<void> deleteSample(String id) async {
    await _api.delete('$_base/samples/$id');
  }

  // ------------------------------- العيوب -------------------------------

  static Future<void> addDefects(String runId, {int twins = 0, int flash = 0, int rejected = 0, String? note}) async {
    await _api.post('$_base/runs/$runId/defects', {
      'twins': twins,
      'flash': flash,
      'rejected': rejected,
      'note': note,
    });
  }

  static Future<void> deleteDefect(String id) async {
    await _api.delete('$_base/defects/$id');
  }

  // ------------------------------- التدخل البشري -------------------------------

  /// [kind]: pressure | twins | dough | clean | adjust | other (other يلزمها [note]).
  static Future<MamoulIntervention> addIntervention(
    String runId, {
    required String kind,
    int? minutes,
    String? note,
  }) async {
    final data = await _api.post('$_base/runs/$runId/interventions', {
      'kind': kind,
      'minutes': minutes,
      'note': note,
    });
    return MamoulIntervention.fromApi(Map<String, dynamic>.from(_map(data)['intervention'] as Map));
  }

  static Future<void> deleteIntervention(String id) async {
    await _api.delete('$_base/interventions/$id');
  }

  // ------------------------------- الأعطال -------------------------------

  /// [status]: 'open' | 'resolved' | null (الكل). بلا مدة → آخر ٩٠ يومًا.
  static Future<MamoulFaultsResult> fetchFaults({
    String? status,
    String? component,
    String? machineId,
    String? from,
    String? to,
  }) async {
    final query = <String, dynamic>{};
    if (status != null) query['status'] = status;
    if (machineId != null) query['machineId'] = machineId;
    if (component != null) query['component'] = component;
    if (from != null && to != null) {
      query['from'] = from;
      query['to'] = to;
    }
    final data = await _api.get('$_base/faults', query: query);
    return MamoulFaultsResult.fromApi(data);
  }

  /// المكينة تُؤخذ من [runId] إن وُجد، وإلا [machineId] إلزامي.
  static Future<MamoulFault> addFault({
    String? machineId,
    required String component,
    String? partLabel,
    required String description,
    String? faultDate,
    String? faultTime,
    int? downtimeMinutes,
    String? actionTaken,
    String? runId,
  }) async {
    final data = await _api.post('$_base/faults', {
      'machineId': machineId,
      'component': component,
      'partLabel': partLabel,
      'description': description,
      'faultDate': faultDate,
      'faultTime': faultTime,
      'downtimeMinutes': downtimeMinutes,
      'actionTaken': actionTaken,
      'runId': runId,
    });
    return MamoulFault.fromApi(Map<String, dynamic>.from(_map(data)['fault'] as Map));
  }

  /// تعديل عطل: كل الحقول تُرسَل (null = مسح)، و[status] اختياري ('open'/'resolved').
  static Future<MamoulFault> updateFault(
    String id, {
    String? machineId,
    required String component,
    String? partLabel,
    required String description,
    required String faultDate,
    String? faultTime,
    int? downtimeMinutes,
    String? actionTaken,
    String? status,
  }) async {
    final data = await _api.patch('$_base/faults/$id', {
      if (machineId != null) 'machineId': machineId,
      'component': component,
      'partLabel': partLabel,
      'description': description,
      'faultDate': faultDate,
      'faultTime': faultTime,
      'downtimeMinutes': downtimeMinutes,
      'actionTaken': actionTaken,
      if (status != null) 'status': status,
    });
    return MamoulFault.fromApi(Map<String, dynamic>.from(_map(data)['fault'] as Map));
  }

  /// تغيير حالة العطل فقط (حلّ/إعادة فتح).
  static Future<MamoulFault> setFaultStatus(String id, String status, {String? actionTaken}) async {
    final data = await _api.patch('$_base/faults/$id', {
      'status': status,
      if (actionTaken != null) 'actionTaken': actionTaken,
    });
    return MamoulFault.fromApi(Map<String, dynamic>.from(_map(data)['fault'] as Map));
  }

  static Future<void> deleteFault(String id) async {
    await _api.delete('$_base/faults/$id');
  }

  // ------------------------------- التحليل -------------------------------

  /// تحليل العيّنات بين تاريخين، مع فلتر اختياري على هدف الوزن وعلى [machineId]
  /// (بلا مكينة = كل المكائن، والنتيجة تحمل جدول مقارنة بينها).
  static Future<MamoulAnalysis> fetchAnalysis({
    required String from,
    required String to,
    double? target,
    String? machineId,
  }) async {
    final query = <String, dynamic>{'from': from, 'to': to};
    if (target != null) query['target'] = target;
    if (machineId != null) query['machineId'] = machineId;
    final data = await _api.get('$_base/analysis', query: query);
    return MamoulAnalysis.fromApi(data);
  }
}

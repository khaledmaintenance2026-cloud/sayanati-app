import 'dart:math';

import 'package:flutter/foundation.dart';

import '../models/mamoul_op_report.dart';
import 'api_client.dart';

/// عدّاد تغيّر تقارير التشغيل/العاملات/التوقيع: أي شاشة تحفظ شيئًا تستدعي
/// [notifyMamoulOpChanged] فتعيد القائمة المفتوحة تحميل بياناتها.
final ValueNotifier<int> mamoulOpChanged = ValueNotifier<int>(0);

void notifyMamoulOpChanged() {
  mamoulOpChanged.value = mamoulOpChanged.value + 1;
}

/// رمز فريد لكل عملية حفظ — يمنع إنشاء التقرير مرتين لو ضُغط «حفظ» مرتين أو
/// أُعيد الإرسال بعد انقطاع الشبكة (السيرفر يعيد نفس التقرير لنفس الرمز).
String newMamoulClientToken() {
  final r = Random.secure();
  final parts = List<String>.generate(4, (_) => r.nextInt(0x7fffffff).toRadixString(16).padLeft(8, '0'));
  return '${DateTime.now().microsecondsSinceEpoch}-${parts.join()}';
}

/// طلبات «تقرير تشغيل المعمول» إلى سيرفر صيانتي (/api/mamoul-reports). كل
/// الدوال ترمي [ApiException] برسالة عربية جاهزة للعرض عند أي خطأ.
class MamoulOpReportService {
  MamoulOpReportService._();

  static final ApiClient _api = ApiClient.instance;
  static const String _base = '/mamoul-reports';

  static Map<String, dynamic> _map(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }

  // ------------------------------ الإعدادات ------------------------------

  static Future<MamoulOpConfig> fetchConfig() async {
    final data = await _api.get('$_base/config');
    return MamoulOpConfig.fromApi(data);
  }

  /// اسم المشغّلة الافتراضي في التقارير الجديدة (مسؤول الإنتاج / مدير النظام).
  static Future<void> setDefaultOperator(String name) async {
    await _api.put('$_base/settings', {'defaultOperator': name});
  }

  /// حفظ توقيع مشغّلة (PNG بصيغة base64). يستبدل توقيعها السابق للتقارير الجديدة
  /// فقط؛ التقارير القديمة تبقى بتوقيعها.
  static Future<void> saveSignature({required String operatorName, required String pngBase64}) async {
    await _api.put('$_base/signatures', {'operatorName': operatorName, 'png': pngBase64});
  }

  // ------------------------------ العاملات ------------------------------

  static Future<List<MamoulWorker>> fetchWorkers({bool all = false}) async {
    final data = await _api.get('$_base/workers', query: all ? {'all': '1'} : null);
    return MamoulWorker.listFromApi(data);
  }

  static Future<MamoulWorker> addWorker({required String name, String? employeeNumber}) async {
    final data = await _api.post('$_base/workers', {'name': name, 'employeeNumber': employeeNumber});
    return MamoulWorker.fromApi(_map(_map(data)['worker']));
  }

  /// تعديل الاسم والرقم الوظيفي (null أو فارغ = بلا رقم).
  static Future<MamoulWorker> updateWorker(String id, {required String name, String? employeeNumber}) async {
    final data = await _api.patch('$_base/workers/$id', {'name': name, 'employeeNumber': employeeNumber});
    return MamoulWorker.fromApi(_map(_map(data)['worker']));
  }

  /// إخفاء العاملة من القائمة (false) أو إظهارها (true). لا حذف: اسمها يبقى في التقارير القديمة.
  static Future<MamoulWorker> setWorkerActive(String id, bool active) async {
    final data = await _api.patch('$_base/workers/$id', {'active': active});
    return MamoulWorker.fromApi(_map(_map(data)['worker']));
  }

  // ------------------------------ التقارير ------------------------------

  /// تقارير يوم واحد (حسب تاريخ تكوير الكرات) مع عددها ومجموع أوزانها.
  static Future<MamoulOpReportsResult> fetchReportsOfDay(String date) async {
    final data = await _api.get('$_base/reports', query: {'date': date});
    return MamoulOpReportsResult.fromApi(data);
  }

  /// بحث برقم الدفعة (أو جزء منه).
  static Future<MamoulOpReportsResult> searchReports(String batchNo) async {
    final data = await _api.get('$_base/reports', query: {'q': batchNo});
    return MamoulOpReportsResult.fromApi(data);
  }

  static Future<MamoulOpReport> fetchReport(String id) async {
    final data = await _api.get('$_base/reports/$id');
    return MamoulOpReport.fromApi(_map(_map(data)['report']));
  }

  static Future<MamoulOpReport> createReport(
    MamoulOpReportDraft draft, {
    required String clientToken,
    bool allowDuplicate = false,
  }) async {
    final data = await _api.post('$_base/reports', {
      ...draft.toApi(),
      'clientToken': clientToken,
      'allowDuplicate': allowDuplicate,
    });
    return MamoulOpReport.fromApi(_map(_map(data)['report']));
  }

  static Future<MamoulOpReport> updateReport(String id, MamoulOpReportDraft draft, {bool allowDuplicate = false}) async {
    final data = await _api.patch('$_base/reports/$id', {
      ...draft.toApi(),
      'allowDuplicate': allowDuplicate,
    });
    return MamoulOpReport.fromApi(_map(_map(data)['report']));
  }

  /// إخفاء التقرير (مسؤول الإنتاج / مدير النظام) — لا يُحذف من قاعدة البيانات.
  static Future<void> hideReport(String id) async {
    await _api.delete('$_base/reports/$id');
  }

  /// نص HTML للتقرير بنفس شكل الورقة، جاهز للطباعة أو التحويل إلى PDF.
  static Future<String> fetchPrintHtml(String id) async {
    final data = await _api.get('$_base/reports/$id/print');
    final html = _map(data)['html'];
    if (html is String && html.isNotEmpty) return html;
    throw ApiException(500, 'تعذّر تجهيز التقرير للطباعة، حاول مرة أخرى');
  }
}

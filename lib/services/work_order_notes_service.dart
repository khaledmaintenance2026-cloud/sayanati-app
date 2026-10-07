import '../models/work_order_note.dart';
import 'api_client.dart';

/// طلبات "ملاحظات المشرف على المهمة" إلى سيرفر صيانتي
/// (/api/work-orders/:id/notes).
///
/// القراءة: مسؤول الصيانة/المدير، والفني المُسنَد للمهمة نفسها فقط.
/// الكتابة: مسؤول الصيانة/المدير فقط. كل الدوال ترمي [ApiException] برسالة
/// عربية جاهزة للعرض عند أي خطأ (صلاحية، مهمة بلا فني، نص فارغ...).
class WorkOrderNotesService {
  WorkOrderNotesService._();

  static final ApiClient _api = ApiClient.instance;

  /// كل ملاحظات المهمة (الأحدث أولًا).
  static Future<List<WorkOrderNote>> fetch(String workOrderId) async {
    final data = await _api.get('/work-orders/$workOrderId/notes');
    return WorkOrderNote.listFromApi(data);
  }

  /// يضيف ملاحظة جديدة؛ السيرفر نفسه يرسلها للجروب وللفنيين بعد الحفظ.
  static Future<WorkOrderNoteAddResult> add(String workOrderId, String note) async {
    final data = await _api.post('/work-orders/$workOrderId/notes', {'note': note});
    final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    final saved = WorkOrderNote.fromApi(Map<String, dynamic>.from(map['note'] as Map));
    final count = (map['notesCount'] as num?)?.round() ?? 1;
    return WorkOrderNoteAddResult(note: saved, count: count);
  }
}

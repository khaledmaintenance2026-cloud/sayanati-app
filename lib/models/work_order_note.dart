/// ملاحظة يكتبها المشرف (مسؤول الصيانة/المدير) على مهمة أو أمر عمل مُسنَد
/// لفني — سواء كانت قيد التنفيذ أو منجزة. تُحفظ على السيرفر كسجل (جدول
/// work_order_notes) وتُرسَل فور كتابتها لجروب الصيانة على واتساب ولكل فني على
/// المهمة (واتساب شخصي + إشعار داخل التطبيق) — راجع routes/workOrders.js.
class WorkOrderNote {
  final String id;
  final String note;

  /// اسم من كتب الملاحظة (المشرف) — قد يكون فارغًا لو حُذف حسابه.
  final String? authorName;

  /// حالة المهمة لحظة كتابة الملاحظة كما يخزّنها السيرفر (in_progress /
  /// waiting_parts / waiting_loto / completed / cancelled).
  final String? workOrderStatus;

  final DateTime createdAt;

  const WorkOrderNote({
    required this.id,
    required this.note,
    this.authorName,
    this.workOrderStatus,
    required this.createdAt,
  });

  factory WorkOrderNote.fromApi(Map<String, dynamic> d) => WorkOrderNote(
        id: d['id'].toString(),
        note: (d['note'] as String?) ?? '',
        authorName: d['author_name'] as String?,
        workOrderStatus: d['work_order_status'] as String?,
        createdAt: DateTime.tryParse(d['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
      );

  /// يقرأ استجابة GET /work-orders/:id/notes ({ "notes": [...] }) — الأحدث أولًا
  /// كما يرتّبها السيرفر.
  static List<WorkOrderNote> listFromApi(dynamic data) {
    final raw = data is Map ? data['notes'] : null;
    if (raw is! List) return <WorkOrderNote>[];
    return raw
        .whereType<Map>()
        .map((m) => WorkOrderNote.fromApi(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// اسم الكاتب جاهزًا للعرض.
  String get authorDisplay {
    final v = authorName?.trim();
    return (v == null || v.isEmpty) ? 'المشرف' : v;
  }

  /// هل كُتبت الملاحظة بعد إنجاز المهمة؟
  bool get wasCompleted => workOrderStatus == 'completed' || workOrderStatus == 'cancelled';

  /// وصف قصير لحالة المهمة وقت كتابة الملاحظة.
  String get statusLabel => wasCompleted ? 'مهمة منجزة' : 'قيد التنفيذ';
}

/// نتيجة إضافة ملاحظة: الملاحظة المحفوظة + العدد الإجمالي لملاحظات المهمة بعدها.
class WorkOrderNoteAddResult {
  final WorkOrderNote note;
  final int count;
  const WorkOrderNoteAddResult({required this.note, required this.count});
}

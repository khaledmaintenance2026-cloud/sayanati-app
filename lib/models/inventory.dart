/// نماذج قسم "المخزون والقطع" الجديد بالصيانة — كتالوج أصناف [InventoryItem]
/// وطلبات قطع [PartRequest] يرفعها الفني وتمر اختياريًا بمرحلة تصميم قبل أن
/// يصرفها مسؤول المخزون فعليًا. راجع routes/inventory.js وschema.sql
/// (جدولا inventory_items وpart_requests) لشرح دورة الحالة الكاملة على
/// السيرفر — هذان النموذجان يعكسانها كما هي بلا أي منطق إضافي هنا.

class InventoryItem {
  final String id;
  final String name;
  final String? category;
  final String unit;
  final int quantity;
  final int? minQuantity;
  final String? notes;

  const InventoryItem({
    required this.id,
    required this.name,
    this.category,
    required this.unit,
    required this.quantity,
    this.minQuantity,
    this.notes,
  });

  /// منخفض — الكمية المتوفرة عند أو تحت الحد الأدنى المحدَّد (لو حُدِّد أصلًا).
  bool get isLow => minQuantity != null && quantity <= minQuantity!;

  factory InventoryItem.fromApi(Map<String, dynamic> d) => InventoryItem(
        id: d['id'].toString(),
        name: (d['name'] as String?) ?? '',
        category: d['category'] as String?,
        unit: (d['unit'] as String?) ?? 'قطعة',
        quantity: (d['quantity'] as num?)?.round() ?? 0,
        minQuantity: (d['min_quantity'] as num?)?.round(),
        notes: d['notes'] as String?,
      );
}

/// حالة طلب القطعة — تطابق عمود status في part_requests على السيرفر تمامًا.
enum PartRequestStatus { pendingDesign, pendingIssue, issued, returned }

PartRequestStatus _statusFromApi(String? s) {
  switch (s) {
    case 'pending_design':
      return PartRequestStatus.pendingDesign;
    case 'issued':
      return PartRequestStatus.issued;
    case 'returned':
      return PartRequestStatus.returned;
    default: // pending_issue
      return PartRequestStatus.pendingIssue;
  }
}

class PartRequest {
  final String id;
  final String? itemId;
  final String itemName;
  final int quantity;
  final String? workOrderId;
  final String? workOrderDescription;
  final String? notes;
  final bool needsDesign;
  final PartRequestStatus status;
  final String requestedBy;
  final String? requestedByUserId;
  final DateTime createdAt;

  final String? designFileUrl;
  final String? designNotes;
  final String? designedBy;
  final DateTime? designedAt;

  final String? issuedBy;
  final DateTime? issuedAt;

  final DateTime? returnedAt;
  final String? returnNotes;

  const PartRequest({
    required this.id,
    this.itemId,
    required this.itemName,
    required this.quantity,
    this.workOrderId,
    this.workOrderDescription,
    this.notes,
    required this.needsDesign,
    required this.status,
    required this.requestedBy,
    this.requestedByUserId,
    required this.createdAt,
    this.designFileUrl,
    this.designNotes,
    this.designedBy,
    this.designedAt,
    this.issuedBy,
    this.issuedAt,
    this.returnedAt,
    this.returnNotes,
  });

  factory PartRequest.fromApi(Map<String, dynamic> d) => PartRequest(
        id: d['id'].toString(),
        itemId: d['item_id']?.toString(),
        itemName: (d['item_name'] as String?) ?? '',
        quantity: (d['quantity'] as num?)?.round() ?? 1,
        workOrderId: d['work_order_id']?.toString(),
        workOrderDescription: d['work_order_description'] as String?,
        notes: d['notes'] as String?,
        needsDesign: (d['needs_design'] as bool?) ?? false,
        status: _statusFromApi(d['status'] as String?),
        requestedBy: (d['requested_by'] as String?) ?? '',
        requestedByUserId: d['requested_by_user']?.toString(),
        createdAt: DateTime.tryParse(d['created_at']?.toString() ?? '') ?? DateTime.now(),
        designFileUrl: d['design_file_url'] as String?,
        designNotes: d['design_notes'] as String?,
        designedBy: d['designed_by'] as String?,
        designedAt: d['designed_at'] == null ? null : DateTime.tryParse(d['designed_at'].toString()),
        issuedBy: d['issued_by'] as String?,
        issuedAt: d['issued_at'] == null ? null : DateTime.tryParse(d['issued_at'].toString()),
        returnedAt: d['returned_at'] == null ? null : DateTime.tryParse(d['returned_at'].toString()),
        returnNotes: d['return_notes'] as String?,
      );
}

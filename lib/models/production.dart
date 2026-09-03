class ProductionLine {
  final String id;
  String name;
  String location;
  bool activeToday;

  ProductionLine({
    required this.id,
    required this.name,
    this.location = 'المستودع العام',
    this.activeToday = true,
  });

  /// يبني خط إنتاج من استجابة سيرفر صيانتي المحلي (جدول production_lines).
  factory ProductionLine.fromApi(Map<String, dynamic> d) => ProductionLine(
        id: d['id'].toString(),
        name: (d['name'] as String?) ?? '',
        location: (d['location'] as String?) ?? 'المستودع العام',
        activeToday: (d['active'] as bool?) ?? true,
      );
}

class Batch {
  final String id;
  final String lineId;
  final String productName;
  final int quantity;
  final DateTime date;
  final bool hasStoppage;
  final String? stoppageReason;
  final int? stoppageMinutes;
  final String recordedBy; // مشرف الخط

  Batch({
    required this.id,
    required this.lineId,
    required this.productName,
    required this.quantity,
    required this.date,
    this.hasStoppage = false,
    this.stoppageReason,
    this.stoppageMinutes,
    required this.recordedBy,
  });
}

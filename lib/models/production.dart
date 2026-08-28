class ProductionLine {
  final String id;
  final String name; // خط ٧
  bool activeToday;

  ProductionLine({required this.id, required this.name, this.activeToday = true});
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

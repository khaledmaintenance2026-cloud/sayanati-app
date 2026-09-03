class Technician {
  final String id;
  String name;
  String specialty;
  String? phone;

  /// حالة الفني كما يخزّنها السيرفر: available (متاح) / busy (مشغول) /
  /// on_leave (إجازة). الواجهات الحالية تتعامل مع هذه القيمة كـ "متاح/غير
  /// متاح" فقط عبر [available] بالأسفل للحفاظ على التوافق مع الشاشات
  /// الموجودة؛ عرض حالة "إجازة" بشكل منفصل في الواجهة إضافة مستقبلية جيدة.
  String status;

  Technician({
    required this.id,
    required this.name,
    required this.specialty,
    this.phone,
    String? status,
    bool? available,
  }) : status = status ?? (available == false ? 'busy' : 'available');

  bool get available => status == 'available';
  set available(bool v) => status = v ? 'available' : 'busy';

  /// الأحرف الأولى من اسم الفني لعرضها داخل دائرة الصورة الرمزية.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1);
    return '${parts[0].substring(0, 1)}.${parts[1].substring(0, 1)}';
  }

  factory Technician.fromApi(Map<String, dynamic> d) => Technician(
        id: d['id'].toString(),
        name: (d['name'] as String?) ?? '',
        specialty: (d['specialty'] as String?) ?? 'عام',
        phone: d['phone'] as String?,
        status: (d['status'] as String?) ?? 'available',
      );
}

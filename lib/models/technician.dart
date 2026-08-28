class Technician {
  final String id;
  final String name;
  final String specialty;
  bool available;

  Technician({
    required this.id,
    required this.name,
    required this.specialty,
    this.available = true,
  });

  /// الأحرف الأولى من اسم الفني لعرضها داخل دائرة الصورة الرمزية.
  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1);
    return '${parts[0].substring(0, 1)}.${parts[1].substring(0, 1)}';
  }
}

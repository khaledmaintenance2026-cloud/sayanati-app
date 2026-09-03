/// أدوات تنسيق عربية: تحويل الأرقام إلى الأرقام الهندية (٠١٢٣...) وتنسيق المدد الزمنية.
class ArabicFormat {
  ArabicFormat._();

  static const _easternDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

  /// يحوّل أي رقم/نص لاتيني إلى أرقام هندية للعرض في واجهات RTL.
  static String toEasternDigits(Object value) {
    final s = value.toString();
    final buffer = StringBuffer();
    for (final ch in s.split('')) {
      final d = int.tryParse(ch);
      buffer.write(d != null ? _easternDigits[d] : ch);
    }
    return buffer.toString();
  }

  /// تنسيق عدد صحيح بفواصل الآلاف بالأرقام الهندية، مثل: ٦٬٣٠٥
  static String number(int value) {
    final s = value.toString();
    final buffer = StringBuffer();
    final reversed = s.split('').reversed.toList();
    for (var i = 0; i < reversed.length; i++) {
      if (i != 0 && i % 3 == 0) buffer.write('٬');
      buffer.write(reversed[i]);
    }
    return toEasternDigits(buffer.toString().split('').reversed.join());
  }

  /// تنسيق مدة زمنية على شكل "٣س ١٠د" أو "٤٥د" حسب الطول.
  static String duration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    if (hours > 0) {
      return '${toEasternDigits(hours)}س ${toEasternDigits(minutes)}د';
    }
    return '${toEasternDigits(minutes)}د';
  }

  /// تنسيق تاريخ ميلادي بأرقام هندية بصيغة يوم/شهر/سنة يفهمها الميدان محليًا.
  static String date(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return toEasternDigits('$y/$m/$d');
  }

  /// تنسيق الوقت بصيغة ٢٤ ساعة بأرقام هندية، مثل ١٤:٠٥.
  static String time(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return toEasternDigits('$h:$m');
  }

  /// تاريخ ووقت معًا لاستخدامهما في رأس التقارير المطبوعة.
  static String dateTime(DateTime dt) => '${date(dt)} — ${time(dt)}';
}

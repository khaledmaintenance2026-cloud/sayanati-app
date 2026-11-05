import 'package:flutter/material.dart';

import 'mamoul_op_reports_tab.dart';

/// شاشة «تقرير تشغيل المعمول» المستقلة (ورقة Mamoul Operating Report QMS-PD-006):
/// تُفتح من زر داخل قسم الإنتاج ← تبويب «مصنع النساء» فقط (طلب المالك 2026-11-05)،
/// وليست ضمن أداة «المعمول» في الصيانة.
class MamoulOpReportsHomeScreen extends StatelessWidget {
  const MamoulOpReportsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تقرير تشغيل المعمول', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: const MamoulOpReportsTab(),
    );
  }
}

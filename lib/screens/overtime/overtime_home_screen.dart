import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'overtime_daily_tab.dart';
import 'overtime_employees_tab.dart';
import 'overtime_reports_tab.dart';
import 'overtime_widgets.dart';

/// شاشة "العمل الإضافي" — تبويب سفلي مخصّص للإداريين فقط (مدير النظام ومسؤول
/// الصيانة، أي نفس شرط canOpenAdminTab في admin_home_screen.dart)؛ لا يظهر
/// للفنيين ولا للأقسام العادية. القيد الملزم فعليًا على السيرفر
/// (routes/overtime.js تطلب دور مسؤول الصيانة فما فوق)، وإخفاء التبويب هنا
/// للواجهة فقط.
///
/// ثلاثة تبويبات داخلية: السجل اليومي (تسجيل الأعمال والأفراد المشاركين)،
/// التقارير (يوم/شهر: عرض وPDF وواتساب)، والأفراد (القائمة الدائمة).
class OvertimeHomeScreen extends StatelessWidget {
  const OvertimeHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('العمل الإضافي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          bottom: const TabBar(
            labelColor: kOvertimeColor,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: kOvertimeColor,
            tabs: [
              Tab(text: 'السجل اليومي'),
              Tab(text: 'التقارير'),
              Tab(text: 'الأفراد'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            OvertimeDailyTab(),
            OvertimeReportsTab(),
            OvertimeEmployeesTab(),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'approvals_tab.dart';
import 'technicians_tab.dart';

/// شاشة الإدارة — للمدير فقط. تبويبان: الفنيون، واعتماد المستخدمين الجدد.
class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الإدارة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          bottom: const TabBar(
            labelColor: AppColors.maintenance,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.maintenance,
            tabs: [
              Tab(text: 'الفنيون'),
              Tab(text: 'اعتماد المستخدمين'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            TechniciansTab(),
            ApprovalsTab(),
          ],
        ),
      ),
    );
  }
}

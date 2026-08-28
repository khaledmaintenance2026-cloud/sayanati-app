import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// جاهز لاحقًا: import 'firebase_options.dart'; import 'package:firebase_core/firebase_core.dart';

import 'services/app_state.dart';
import 'theme/app_theme.dart';
import 'screens/home/home_screen.dart';
import 'screens/maintenance/maintenance_dashboard_screen.dart';
import 'screens/production/production_lines_screen.dart';
import 'screens/safety/safety_home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // TODO: بعد تنفيذ خطوات lib/services/firebase_bootstrap.dart فعّلوا السطر التالي:
  // await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const SayanatiApp());
}

class SayanatiApp extends StatelessWidget {
  const SayanatiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..seedAll(),
      child: MaterialApp(
        title: 'صيانتي',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        builder: (context, child) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          );
        },
        home: const RootNav(),
      ),
    );
  }
}

/// الحاوية الرئيسية: شريط تنقل سفلي حقيقي يربط الرئيسية بالأقسام الثلاثة.
/// كل شاشة فرعية (بلاغ جديد، تعيين فني، إغلاق بلاغ...) تُفتح فوق هذا الجذر
/// عبر Navigator.push، ولا تعرض شريط التنقل السفلي بنفسها.
class RootNav extends StatefulWidget {
  const RootNav({super.key});

  @override
  State<RootNav> createState() => _RootNavState();
}

class _RootNavState extends State<RootNav> {
  int _index = 0;

  void _goToTab(int i) => setState(() => _index = i);

  @override
  Widget build(BuildContext context) {
    final tabs = [
      HomeScreen(onSelectTab: _goToTab),
      const MaintenanceDashboardScreen(),
      const ProductionLinesScreen(),
      const SafetyHomeScreen(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.maintenance,
        unselectedItemColor: AppColors.textFaint,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.build_outlined), label: 'الصيانة'),
          BottomNavigationBarItem(icon: Icon(Icons.factory_outlined), label: 'الإنتاج'),
          BottomNavigationBarItem(icon: Icon(Icons.shield_outlined), label: 'السلامة'),
        ],
      ),
    );
  }
}

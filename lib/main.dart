import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/app_state.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/pending_approval_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/maintenance/maintenance_dashboard_screen.dart';
import 'screens/production/production_lines_screen.dart';
import 'screens/safety/safety_home_screen.dart';
import 'screens/admin/admin_home_screen.dart';

void main() {
  runApp(const SayanatiApp());
}

class SayanatiApp extends StatelessWidget {
  const SayanatiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => AppState()..seedAll()),
      ],
      child: MaterialApp(
        title: 'صيانتي',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        // ملاحظة: لا نضبط locale/localizationsDelegates هنا عمدًا — لو حدّدنا
        // locale بدون حزمة flutter_localizations الرسمية، فلن يجد Flutter
        // ترجمة MaterialLocalizations للعربية وسيتوقف التطبيق فور بدء التشغيل.
        // كل نصوص الواجهة عندنا مكتوبة عربيًا يدويًا مباشرة، والاتجاه من
        // اليمين لليسار مضمون بالكامل عبر Directionality بالأسفل، فلا حاجة
        // لضبط locale إطلاقًا.
        builder: (context, child) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          );
        },
        home: const AuthGate(),
      ),
    );
  }
}

/// يقرر أي شاشة تظهر حسب حالة تسجيل الدخول: دخول/تسجيل، بانتظار الاعتماد،
/// أو الواجهة الرئيسية — ويربط AppState بمزوّد رمز الدخول فور تسجيل الدخول
/// لتفعيل تحميل الفنيين من Firestore.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _attached = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (auth.status == AuthStatus.signedIn && !_attached) {
      _attached = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<AppState>().attachAuth();
      });
    } else if (auth.status != AuthStatus.signedIn && _attached) {
      _attached = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<AppState>().detachAuth();
      });
    }

    switch (auth.status) {
      case AuthStatus.loading:
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      case AuthStatus.signedOut:
        return const LoginScreen();
      case AuthStatus.pendingApproval:
        return const PendingApprovalScreen();
      case AuthStatus.signedIn:
        return const RootNav();
    }
  }
}

/// الحاوية الرئيسية: شريط تنقل سفلي يُبنى حسب دور المستخدم — كل دور يرى
/// قسمه فقط + الرئيسية، والمدير يرى كل الأقسام + الإدارة.
class RootNav extends StatefulWidget {
  const RootNav({super.key});

  @override
  State<RootNav> createState() => _RootNavState();
}

class _RootNavState extends State<RootNav> {
  int _index = 0;

  void _goToModule(String key) {
    final tabs = _buildKeys(context);
    final target = tabs.indexOf(key);
    if (target != -1) setState(() => _index = target);
  }

  List<String> _buildKeys(BuildContext context) {
    final role = context.read<AuthService>().currentUser?.role ?? AppRole.production;
    final keys = <String>['home'];
    if (role == AppRole.admin || role == AppRole.maintenance) keys.add('maintenance');
    if (role == AppRole.admin || role == AppRole.production) keys.add('production');
    if (role == AppRole.admin || role == AppRole.safety) keys.add('safety');
    if (role == AppRole.admin) keys.add('admin');
    return keys;
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthService>().currentUser?.role ?? AppRole.production;
    final keys = _buildKeys(context);

    final screens = <String, Widget>{
      'home': HomeScreen(role: role, onSelectModule: _goToModule),
      'maintenance': const MaintenanceDashboardScreen(),
      'production': const ProductionLinesScreen(),
      'safety': const SafetyHomeScreen(),
      'admin': const AdminHomeScreen(),
    };
    final items = <String, BottomNavigationBarItem>{
      'home': const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'الرئيسية'),
      'maintenance': const BottomNavigationBarItem(icon: Icon(Icons.build_outlined), label: 'الصيانة'),
      'production': const BottomNavigationBarItem(icon: Icon(Icons.factory_outlined), label: 'الإنتاج'),
      'safety': const BottomNavigationBarItem(icon: Icon(Icons.shield_outlined), label: 'السلامة'),
      'admin': const BottomNavigationBarItem(icon: Icon(Icons.admin_panel_settings_outlined), label: 'الإدارة'),
    };

    final index = _index.clamp(0, keys.length - 1);

    return Scaffold(
      body: IndexedStack(index: index, children: keys.map((k) => screens[k]!).toList()),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => setState(() => _index = i),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.maintenance,
        unselectedItemColor: AppColors.textFaint,
        showUnselectedLabels: true,
        items: keys.map((k) => items[k]!).toList(),
      ),
    );
  }
}

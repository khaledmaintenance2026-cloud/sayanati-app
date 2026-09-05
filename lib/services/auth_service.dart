import 'package:flutter/foundation.dart';

import 'api_client.dart';

/// أدوار المستخدمين داخل التطبيق. كل دور يرى قسمه فقط + الرئيسية،
/// عدا "مدير النظام" الذي يرى كل الأقسام + لوحة الإدارة.
///
/// نفس القيم بالضبط المستخدمة في عمود role بجدول users على سيرفر صيانتي
/// المحلي (راجع schema.sql) — لا حاجة لأي تحويل بين الطرفين.
enum AppRole { admin, maintenance, production, safety }

AppRole roleFromString(String? s) {
  switch (s) {
    case 'admin':
      return AppRole.admin;
    case 'maintenance':
      return AppRole.maintenance;
    case 'production':
      return AppRole.production;
    case 'safety':
      return AppRole.safety;
    default:
      return AppRole.production;
  }
}

String roleToString(AppRole r) => r.name;

String roleLabel(AppRole r) {
  switch (r) {
    case AppRole.admin:
      return 'مدير النظام';
    case AppRole.maintenance:
      return 'الصيانة';
    case AppRole.production:
      return 'الإنتاج';
    case AppRole.safety:
      return 'السلامة';
  }
}

class AppUser {
  final String uid;
  final String email;
  final String name;
  final AppRole role;
  final bool approved;

  /// المصنع الذي يُقيَّد به مستخدم قسم الإنتاج (مصنع الرجال/مصنع النساء) —
  /// null يعني بلا تقييد (يرى كل المصانع)، وهذا حال كل الأدوار الأخرى دائمًا.
  /// يُحدَّد فقط من لوحة الإدارة (راجع PATCH /users/:id/production-facility).
  final String? productionFacility;

  AppUser({
    required this.uid,
    required this.email,
    required this.name,
    required this.role,
    required this.approved,
    this.productionFacility,
  });

  /// يبني مستخدمًا من استجابة سيرفر صيانتي المحلي (حقل "user" في ردود
  /// /api/auth/* و /api/users) — الشكل: {id, name, email, role, status,
  /// production_facility}.
  factory AppUser.fromApi(Map<String, dynamic> d) => AppUser(
        uid: d['id'].toString(),
        email: (d['email'] as String?) ?? '',
        name: (d['name'] as String?) ?? '',
        role: roleFromString(d['role'] as String?),
        approved: d['status'] == 'approved',
        productionFacility: d['production_facility'] as String?,
      );
}

enum AuthStatus { loading, signedOut, pendingApproval, signedIn }

/// خدمة الدخول/الجلسة — تتحدث الآن مع سيرفر صيانتي المحلي (Node.js +
/// PostgreSQL) عبر [ApiClient] بدل Firebase Authentication + Cloud Firestore.
///
/// أُبقيت الواجهة العامة (status / currentUser / lastError / signIn / signUp
/// / signOut / validIdToken / refreshProfile) كما هي بالضبط عمدًا، حتى لا
/// تحتاج أي شاشة تستخدم AuthService لأي تعديل بعد هذا الاستبدال.
class AuthService extends ChangeNotifier {
  final ApiClient _api = ApiClient.instance;

  AppUser? currentUser;
  AuthStatus status = AuthStatus.loading;
  String? lastError;

  AuthService() {
    _restoreSession();
  }

  Future<void> _restoreSession() async {
    final token = await _api.loadPersistedToken();
    if (token == null) {
      status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }
    try {
      final data = await _api.get('/auth/me');
      currentUser = AppUser.fromApi(data['user'] as Map<String, dynamic>);
      status = currentUser!.approved ? AuthStatus.signedIn : AuthStatus.pendingApproval;
    } catch (e) {
      // الرمز المحفوظ لم يعد صالحًا (انتهت صلاحيته، أو أُلغي اعتماد الحساب
      // وحُذف) — وليس بالضرورة خطأ شبكة عابر؛ في حالة تعذّر الاتصال نُبقي
      // المستخدم في وضع "غير مسجّل" ونعرض السبب بدل تسجيل خروج صامت مربك.
      await _api.clearToken();
      status = AuthStatus.signedOut;
      if (e is ApiException && e.isConnectionError) lastError = e.message;
    }
    notifyListeners();
  }

  /// أُبقي هذا الاسم والنوع (Future<String>) للتوافق مع أي كود قديم ينتظر
  /// رمز دخول Firebase-style؛ عمليًا رمز صيانتي المحلي (JWT) صالح لمدة ٣٠
  /// يومًا ولا يحتاج تجديدًا دوريًا كما كان الحال مع Firebase (كل ساعة).
  Future<String> get validIdToken async {
    if (!_api.hasToken) throw Exception('غير مسجّل الدخول');
    return 'session'; // القيمة نفسها غير مستخدَمة فعليًا الآن — ApiClient يرفق الرمز الحقيقي تلقائيًا بكل طلب.
  }

  Future<bool> signIn(String email, String password) async {
    lastError = null;
    try {
      final data = await _api.post('/auth/login', {
        'email': email.trim(),
        'password': password,
      });
      await _api.setToken(data['token'] as String);
      currentUser = AppUser.fromApi(data['user'] as Map<String, dynamic>);
      status = currentUser!.approved ? AuthStatus.signedIn : AuthStatus.pendingApproval;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      lastError = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signUp(String name, String email, String password) async {
    lastError = null;
    try {
      final data = await _api.post('/auth/register', {
        'name': name.trim(),
        'email': email.trim(),
        'password': password,
      });
      await _api.setToken(data['token'] as String);
      currentUser = AppUser.fromApi(data['user'] as Map<String, dynamic>);
      status = currentUser!.approved ? AuthStatus.signedIn : AuthStatus.pendingApproval;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      lastError = e.message;
      notifyListeners();
      return false;
    }
  }

  /// يُستدعى من شاشة "بانتظار الاعتماد" عند الضغط على زر التحديث، ومن
  /// لوحة الإدارة بعد أي تغيير على المستخدم الحالي نفسه.
  Future<void> refreshProfile() async {
    if (currentUser == null) return;
    try {
      final data = await _api.get('/auth/me');
      currentUser = AppUser.fromApi(data['user'] as Map<String, dynamic>);
      status = currentUser!.approved ? AuthStatus.signedIn : AuthStatus.pendingApproval;
      notifyListeners();
    } on ApiException catch (e) {
      // لو رفض السيرفر الرمز (401) فهذا يعني إلغاء الحساب أو حذفه من قِبل
      // المدير أثناء انتظار الاعتماد — نسجّل خروجًا فعليًا في هذه الحالة فقط.
      if (e.statusCode == 401) await signOut();
    }
  }

  Future<void> signOut() async {
    await _api.clearToken();
    currentUser = null;
    lastError = null;
    status = AuthStatus.signedOut;
    notifyListeners();
  }
}

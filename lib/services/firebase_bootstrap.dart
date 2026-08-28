// هذا الملف جاهز لتفعيل Firebase عند توفر مشروعكم الخاص، ولا يُستخدم حاليًا.
//
// خطوات التفعيل لاحقًا (تستغرق دقائق):
// 1) أنشئوا مشروع Firebase مجاني على https://console.firebase.google.com
// 2) في pubspec.yaml أضيفوا تحت dependencies:
//      firebase_core: ^3.6.0
//      cloud_firestore: ^5.4.4
//      firebase_auth: ^5.3.1
//      firebase_messaging: ^15.1.3
// 3) ثبّتوا أداة FlutterFire: `dart pub global activate flutterfire_cli`
// 4) داخل مجلد المشروع نفّذوا: `flutterfire configure`
//    سيولّد هذا تلقائيًا ملف lib/firebase_options.dart بمعرّفات مشروعكم.
// 5) في lib/main.dart، فعّلوا استدعاء Firebase.initializeApp(...) بالأسفل
//    (موجود ومُعلَّق حاليًا بعلامة TODO) بدلاً من AppState المحلي.
// 6) استبدلوا التخزين المحلي في lib/services/app_state.dart بقراءة/كتابة
//    من Cloud Firestore (المجموعات المقترحة: reports, technicians, batches,
//    permits) — البنية (Models) في lib/models/ جاهزة لهذا الاستبدال دون
//    تغيير أي شاشة.

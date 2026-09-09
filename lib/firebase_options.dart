import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    return android;
  }

  static const web = FirebaseOptions(
    apiKey: 'AIzaSyDDafUMEXWmqCzg-EDtoQ_p7TiG-0y7IXg',
    appId: '1:367976973063:web:01025c456422381dd23ba2',
    messagingSenderId: '367976973063',
    projectId: 'sayanati-bb99b',
    authDomain: 'sayanati-bb99b.firebaseapp.com',
    storageBucket: 'sayanati-bb99b.firebasestorage.app',
    measurementId: 'G-2YB04FS6QT',
  );

  static const android = FirebaseOptions(
    apiKey: 'AIzaSyAiqZ6HmgBAbYfK12iUYc6p6BmyDDBcPCs',
    appId: '1:367976973063:android:9cb491f3a643cbcbd23ba2',
    messagingSenderId: '367976973063',
    projectId: 'sayanati-bb99b',
    storageBucket: 'sayanati-bb99b.firebasestorage.app',
  );
}

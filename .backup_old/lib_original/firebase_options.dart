// File generated for Firebase project: docushare-th2-3a9b
// Platforms: Android, Web
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Cấu hình mặc định cho Firebase kết nối dự án thực tế DocuShare
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for iOS - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macOS - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for Windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for Linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDnbFkGFtOgw5F7Vp1ImVTKYGJNabpBr7o',
    appId: '1:274311267982:web:c17873e1199deba449ebdf',
    messagingSenderId: '274311267982',
    projectId: 'docushare-th2-3a9b',
    authDomain: 'docushare-th2-3a9b.firebaseapp.com',
    storageBucket: 'docushare-th2-3a9b.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBHYcHiNsxY4O6gaIfl_N09C1lA5XUnT9E',
    appId: '1:274311267982:android:2d2980c23743ade049ebdf',
    messagingSenderId: '274311267982',
    projectId: 'docushare-th2-3a9b',
    storageBucket: 'docushare-th2-3a9b.firebasestorage.app',
  );
}

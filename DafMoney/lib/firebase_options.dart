import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCIOgNLDf0-3cGmCwLJLK69xdCWE2Hc2JU',
    appId: '1:502701571624:web:37ccc06dbec24342f8ff1d',
    messagingSenderId: '502701571624',
    projectId: 'dafmoney',
    authDomain: 'dafmoney.firebaseapp.com',
    storageBucket: 'dafmoney.firebasestorage.app',
    measurementId: 'G-5KWQYY2Y6P',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDvn2Wlk1N5Sm9LQ2GI5O5nqo2kFDC0fL4',
    appId: '1:502701571624:android:e0bb10fbdaa7d754f8ff1d',
    messagingSenderId: '502701571624',
    projectId: 'dafmoney',
    storageBucket: 'dafmoney.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC9OkuCyUQq1cg_sT7aMQqPEjMetsVpi7w',
    appId: '1:502701571624:ios:09d3286d627f325df8ff1d',
    messagingSenderId: '502701571624',
    projectId: 'dafmoney',
    storageBucket: 'dafmoney.firebasestorage.app',
    iosBundleId: 'com.example.keuangan',
  );
}

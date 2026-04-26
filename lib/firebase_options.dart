import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, debugPrint;

/// Firebase options loaded from build-time defines so API keys are not committed.
///
/// Example:
/// flutter run --dart-define=FIREBASE_ANDROID_API_KEY=... --dart-define=FIREBASE_IOS_API_KEY=... --dart-define=FIREBASE_WEB_API_KEY=...
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
          'DefaultFirebaseOptions have not been configured for macos.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static FirebaseOptions get web => FirebaseOptions(
    apiKey: _requiredDefine('FIREBASE_WEB_API_KEY'),
    appId: '1:232896256276:web:95ba557b1df6e40ccc4a01',
    messagingSenderId: '232896256276',
    projectId: 'careos-sanctuary-7b2a9',
    authDomain: 'careos-sanctuary-7b2a9.firebaseapp.com',
    storageBucket: 'careos-sanctuary-7b2a9.firebasestorage.app',
  );

  static FirebaseOptions get android => FirebaseOptions(
    apiKey: _requiredDefine('FIREBASE_ANDROID_API_KEY'),
    appId: '1:232896256276:android:6f72b0a59709ab15cc4a01',
    messagingSenderId: '232896256276',
    projectId: 'careos-sanctuary-7b2a9',
    storageBucket: 'careos-sanctuary-7b2a9.firebasestorage.app',
  );

  static FirebaseOptions get ios => FirebaseOptions(
    apiKey: _requiredDefine('FIREBASE_IOS_API_KEY'),
    appId: '1:232896256276:ios:93cffba48df3b70bcc4a01',
    messagingSenderId: '232896256276',
    projectId: 'careos-sanctuary-7b2a9',
    storageBucket: 'careos-sanctuary-7b2a9.firebasestorage.app',
    iosBundleId: 'com.example.careos',
  );

  static String _requiredDefine(String key) {
    const webKey = String.fromEnvironment('FIREBASE_WEB_API_KEY');
    const androidKey = String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
    const iosKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');

    final value = switch (key) {
      'FIREBASE_WEB_API_KEY' => webKey,
      'FIREBASE_ANDROID_API_KEY' => androidKey,
      'FIREBASE_IOS_API_KEY' => iosKey,
      _ => '',
    };

    if (value.isEmpty) {
      debugPrint(
        'Warning: Missing required --dart-define for $key. Using placeholder. App may not work properly.',
      );
      return 'placeholder_key'; // Return a placeholder to prevent crash
    }
    return value;
  }
}

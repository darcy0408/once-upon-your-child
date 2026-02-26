import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCZ1NygwMgnjeePxFbS_dd0fnBEqIsUN2o',
    appId: '1:704377355929:android:32df311d27d46856958208',
    messagingSenderId: '704377355929',
    projectId: 'story-weaver-7c279',
    storageBucket: 'story-weaver-7c279.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyBWB8xlHESYTsjPjttSCJaQ6mSdoW9AfkE',
    appId: '1:704377355929:ios:f038a17e18b0b316958208',
    messagingSenderId: '704377355929',
    projectId: 'story-weaver-7c279',
    storageBucket: 'story-weaver-7c279.firebasestorage.app',
    iosBundleId: 'com.storyweaver.storyWeaverApp',
  );
}

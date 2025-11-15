import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    // For web deployment without Firebase configuration
    // Return null options that will cause Firebase to fail gracefully
    return const FirebaseOptions(
      apiKey: 'demo-key',
      appId: 'demo-app-id',
      messagingSenderId: '123456789',
      projectId: 'demo-project',
    );
  }
}

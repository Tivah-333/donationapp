import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

class DefaultFirebaseOptions {
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: 'YOUR_APP_ID',
    messagingSenderId: 'YOUR_MESSAGING_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    authDomain: 'your-app.firebaseapp.com',
    storageBucket: 'your-app.appspot.com',
    measurementId: 'YOUR_MEASUREMENT_ID',
  );

  static FirebaseOptions get currentPlatform {
    return web; // Only web supported for now
  }
}
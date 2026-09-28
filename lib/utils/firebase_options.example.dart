// Bu dosyayı firebase_options.dart adıyla kopyalayıp kendi Firebase
// projenizin değerleriyle doldurun (ya da `flutterfire configure` çalıştırın).
// Gerçek firebase_options.dart depoya girmez.
import 'package:firebase_core/firebase_core.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => android;

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'YOUR_API_KEY',
    appId: 'YOUR_APP_ID',
    messagingSenderId: 'YOUR_SENDER_ID',
    projectId: 'YOUR_PROJECT_ID',
    storageBucket: 'YOUR_PROJECT_ID.firebasestorage.app',
  );
}

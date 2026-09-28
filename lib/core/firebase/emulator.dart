import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Yerel Firebase emülatörüyle çalışmak için:
///   flutter run --dart-define=USE_FIREBASE_EMULATOR=true
/// Android emülatöründen bilgisayara 10.0.2.2 ile ulaşılır; gerçek cihazda
/// `--dart-define=EMULATOR_HOST=192.168.x.x` (bilgisayarın IP adresi) verilir.
const bool useFirebaseEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');
const String emulatorHost = String.fromEnvironment(
  'EMULATOR_HOST',
  defaultValue: '10.0.2.2',
);

Future<void> connectToEmulators() async {
  if (!useFirebaseEmulator) return;
  await FirebaseAuth.instance.useAuthEmulator(emulatorHost, 9099);
  FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost, 8080);
}

/// Ek FirebaseApp örneklerinin (ör. teknisyen hesabı açan yardımcı app)
/// Auth istemcisini de emülatöre yönlendirir.
Future<void> connectAuthToEmulator(FirebaseAuth auth) async {
  if (!useFirebaseEmulator) return;
  await auth.useAuthEmulator(emulatorHost, 9099);
}

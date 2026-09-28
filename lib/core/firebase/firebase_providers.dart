import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Firebase nesneleri de provider üzerinden verilir. Böylece testte
/// `ProviderScope(overrides: [...])` ile sahte (fake) sürümleri
/// verilebilir; repository'ler `FirebaseFirestore.instance`'a doğrudan
/// bağlı kalmaz.
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

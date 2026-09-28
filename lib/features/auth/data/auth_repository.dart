import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobil_proje/core/firebase/firebase_providers.dart';
import 'package:mobil_proje/features/auth/domain/user_role.dart';
import 'package:mobil_proje/features/customers/data/customer_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
    ref.watch(customerRepositoryProvider),
  ),
);

/// Giriş, kayıt, çıkış ve rol bulma. Ekranlar FirebaseAuth'u doğrudan
/// kullanmaz.
class AuthRepository {
  AuthRepository(this._auth, this._db, this._customers);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  final CustomerRepository _customers;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> signIn({required String email, required String password}) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<void> signOut() => _auth.signOut();

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  /// Müşteri kaydı: hesap açılır, doğrulama e-postası gönderilir ve müşteri
  /// belgesi yazılır. Kullanıcı oturumda kalır; yönlendirici onu doğrulama
  /// ekranına götürür.
  Future<void> registerCustomer({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user!;
    await user.sendEmailVerification();
    await _customers.create(user.uid, name: name, email: email, phone: phone);
  }

  Future<void> resendVerificationEmail() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  /// Kullanıcıyı sunucudan yeniler; e-posta doğrulandıysa true döner.
  /// Doğrulandıysa token da yenilenir ki firestore.rules yeni durumu
  /// (`email_verified`) görsün.
  Future<bool> reloadAndCheckVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final refreshed = _auth.currentUser;
    if (refreshed == null || !refreshed.emailVerified) return false;
    await refreshed.getIdToken(true);
    return true;
  }

  /// Kullanıcının rolünü, kaydının bulunduğu koleksiyondan bulur.
  /// Sıra firestore.rules içindeki role() ile aynıdır.
  ///
  /// Kayıttan hemen sonra müşteri belgesi henüz yazılmamış olabilir; bu
  /// yüzden rol bulunamazsa birkaç kez kısa aralıklarla tekrar denenir.
  Future<UserRole?> findUserRole(String uid, {int retries = 3}) async {
    const collections = {
      'customers': UserRole.customer,
      'technicians': UserRole.technician,
      'companies': UserRole.company,
    };

    for (var attempt = 0; attempt <= retries; attempt++) {
      for (final entry in collections.entries) {
        final doc = await _db.collection(entry.key).doc(uid).get();
        if (doc.exists) return entry.value;
      }
      if (attempt < retries) {
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
    }
    return null;
  }
}

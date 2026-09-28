import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobil_proje/features/auth/data/auth_repository.dart';
import 'package:mobil_proje/features/auth/domain/session.dart';

/// Firebase'in oturum akışı: giriş yapınca kullanıcı, çıkınca null.
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

/// Oturum durumu: giriş yok / doğrulama bekliyor / giriş yapıldı (rol) /
/// geçersiz. Kullanıcı değişince (giriş-çıkış) kendiliğinden yeniden
/// hesaplanır. E-posta doğrulandıktan sonra `ref.invalidate(sessionProvider)`
/// ile elle yenilenir.
final sessionProvider = FutureProvider<Session>((ref) async {
  final user = await ref.watch(authStateProvider.future);
  if (user == null) return const SignedOut();

  final repo = ref.watch(authRepositoryProvider);
  // reload() sonrası güncel emailVerified değeri currentUser'dadır.
  final current = repo.currentUser ?? user;

  try {
    final role = await repo.findUserRole(user.uid);
    if (role == null) {
      debugPrint('Kullanıcı rolü bulunamadı: UID => ${user.uid}');
    }
    return resolveSession(
      uid: user.uid,
      email: current.email,
      emailVerified: current.emailVerified,
      role: role,
    );
  } catch (e) {
    debugPrint('Rol okuma hatası: $e');
    return const InvalidSession(SessionProblem.error);
  }
});

/// Giriş yapmış kullanıcının uid'si; giriş yoksa null.
final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).valueOrNull?.uid,
);

/// Oturum kapatıldıktan sonra giriş ekranında bir kez gösterilecek mesaj.
final loginMessageProvider = NotifierProvider<LoginMessage, String?>(
  LoginMessage.new,
);

class LoginMessage extends Notifier<String?> {
  @override
  String? build() => null;

  void show(String message) => state = message;

  void clear() => state = null;
}

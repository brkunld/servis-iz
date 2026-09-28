import 'package:flutter/foundation.dart';

import 'package:mobil_proje/features/auth/domain/user_role.dart';

/// Uygulamanın o anki oturum durumu. Yönlendirici (router) hangi ekranın
/// açılacağına buna bakarak karar verir.
///
/// `sealed` olduğu için `switch` bütün durumları ele almak zorundadır;
/// yeni bir durum eklenirse derleyici eksik yerleri gösterir.
@immutable
sealed class Session {
  const Session();
}

/// Kimse giriş yapmamış.
class SignedOut extends Session {
  const SignedOut();
}

/// Müşteri giriş yaptı ama e-postasını henüz doğrulamadı.
class VerificationRequired extends Session {
  const VerificationRequired({required this.uid, this.email});

  final String uid;
  final String? email;
}

/// Giriş yapılmış ve rol belli.
class SignedIn extends Session {
  const SignedIn({required this.uid, required this.role, this.email});

  final String uid;
  final UserRole role;
  final String? email;
}

/// Giriş yapılmış ama oturum kullanılamıyor (rol yok ya da okunamadı).
/// Uygulama bu durumda oturumu kapatıp giriş ekranında [problem] mesajını
/// gösterir.
class InvalidSession extends Session {
  const InvalidSession(this.problem);

  final SessionProblem problem;
}

enum SessionProblem {
  noRole('Hesabınız bir role bağlı değil. Lütfen tekrar giriş yapın.'),
  error('Bir hata oluştu. Lütfen tekrar giriş yapın.');

  const SessionProblem(this.message);

  final String message;
}

/// Firebase kullanıcısı ve bulunan rolden oturum durumunu hesaplar.
///
/// Müşteriler kendi kendine kayıt olduğu için e-posta doğrulaması
/// zorunludur; şirket ve teknisyen hesaplarını güvenilir taraflar açar.
/// Rol henüz bulunamadıysa (kayıt yeni yapıldı, müşteri belgesi yazılıyor)
/// kullanıcı da doğrulama bekleyen müşteri sayılır; böylece kayıt sırasında
/// oturum kapatılmaz.
Session resolveSession({
  required String uid,
  required bool emailVerified,
  required UserRole? role,
  String? email,
}) {
  final mayNeedVerification = role == null || role == UserRole.customer;
  if (mayNeedVerification && !emailVerified) {
    return VerificationRequired(uid: uid, email: email);
  }
  if (role == null) return const InvalidSession(SessionProblem.noRole);
  return SignedIn(uid: uid, role: role, email: email);
}

import 'package:mobil_proje/core/router/app_routes.dart';
import 'package:mobil_proje/features/auth/domain/session.dart';

/// Yönlendirme kuralı: oturum durumuna ve gidilmek istenen adrese bakıp
/// kullanıcıyı başka bir adrese göndermek gerekiyorsa o adresi, gerekmiyorsa
/// null döndürür.
///
/// Saf bir fonksiyondur (Firebase'e, widget'a bağlı değil); bu yüzden
/// birim testiyle doğrudan denenebilir. go_router her gezinmede ve oturum
/// her değiştiğinde bunu çağırır.
///
/// [session] null ise oturum henüz ilk kez yükleniyordur.
String? authRedirect(Session? session, String location) {
  switch (session) {
    case null:
      return location == AppRoutes.splash ? null : AppRoutes.splash;

    case SignedOut() || InvalidSession():
      const publicPaths = {AppRoutes.login, AppRoutes.register};
      return publicPaths.contains(location) ? null : AppRoutes.login;

    case VerificationRequired():
      return location == AppRoutes.verifyEmail ? null : AppRoutes.verifyEmail;

    case SignedIn(:final role):
      final allowed = AppRoutes.allowedPrefixes(
        role,
      ).any((prefix) => location == prefix || location.startsWith('$prefix/'));
      return allowed ? null : AppRoutes.homeFor(role);
  }
}

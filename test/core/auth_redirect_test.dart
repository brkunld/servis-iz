import 'package:flutter_test/flutter_test.dart';
import 'package:mobil_proje/core/router/app_routes.dart';
import 'package:mobil_proje/core/router/auth_redirect.dart';
import 'package:mobil_proje/features/auth/domain/session.dart';
import 'package:mobil_proje/features/auth/domain/user_role.dart';

void main() {
  SignedIn signedIn(UserRole role) => SignedIn(uid: 'u', role: role);

  group('authRedirect', () {
    test('oturum yüklenirken açılış ekranında beklenir', () {
      expect(authRedirect(null, AppRoutes.splash), isNull);
      expect(authRedirect(null, AppRoutes.customer), AppRoutes.splash);
    });

    test('giriş yapmamış kullanıcı yalnız giriş ve kayıt görür', () {
      const s = SignedOut();
      expect(authRedirect(s, AppRoutes.login), isNull);
      expect(authRedirect(s, AppRoutes.register), isNull);
      expect(authRedirect(s, AppRoutes.splash), AppRoutes.login);
      expect(authRedirect(s, AppRoutes.company), AppRoutes.login);
    });

    test('geçersiz oturum giriş ekranına gider', () {
      const s = InvalidSession(SessionProblem.noRole);
      expect(authRedirect(s, AppRoutes.customer), AppRoutes.login);
    });

    test('doğrulama bekleyen müşteri doğrulama ekranında kalır', () {
      const s = VerificationRequired(uid: 'u');
      expect(authRedirect(s, AppRoutes.register), AppRoutes.verifyEmail);
      expect(authRedirect(s, AppRoutes.customer), AppRoutes.verifyEmail);
      expect(authRedirect(s, AppRoutes.verifyEmail), isNull);
    });

    test('giriş yapan kullanıcı rolünün ana ekranına gider', () {
      expect(
        authRedirect(signedIn(UserRole.customer), AppRoutes.login),
        AppRoutes.customer,
      );
      expect(
        authRedirect(signedIn(UserRole.technician), AppRoutes.splash),
        AppRoutes.technician,
      );
      expect(
        authRedirect(signedIn(UserRole.company), AppRoutes.verifyEmail),
        AppRoutes.company,
      );
    });

    test('rol başka rolün ekranına giremez', () {
      expect(
        authRedirect(signedIn(UserRole.customer), AppRoutes.company),
        AppRoutes.customer,
      );
      expect(
        authRedirect(signedIn(UserRole.technician), AppRoutes.addTechnician),
        AppRoutes.technician,
      );
      // Şirket sohbet ekranını kullanmaz.
      expect(
        authRedirect(signedIn(UserRole.company), '/chat/r1'),
        AppRoutes.company,
      );
      // "/customerX" gibi benzer ama farklı adresler de engellenir.
      expect(
        authRedirect(signedIn(UserRole.customer), '/customerX'),
        AppRoutes.customer,
      );
    });

    test('rol kendi ve ortak ekranlarına girebilir', () {
      final customer = signedIn(UserRole.customer);
      expect(authRedirect(customer, AppRoutes.newRequest), isNull);
      expect(authRedirect(customer, AppRoutes.pickLocation), isNull);
      expect(authRedirect(customer, '/chat/r1'), isNull);
      expect(authRedirect(customer, AppRoutes.mapBase), isNull);

      final company = signedIn(UserRole.company);
      expect(authRedirect(company, AppRoutes.editTechnician('t1')), isNull);
      expect(authRedirect(company, AppRoutes.mapBase), isNull);
    });
  });

  group('AppRoutes', () {
    test('sohbet adresi talep ve tarafları taşır', () {
      final uri = Uri.parse(
        AppRoutes.chat(requestId: 'r1', customerId: 'c1', technicianId: 't1'),
      );
      expect(uri.path, '/chat/r1');
      expect(uri.queryParameters, {'customer': 'c1', 'technician': 't1'});
    });

    test('harita adresi yalnız verilen bilgileri taşır', () {
      final uri = Uri.parse(
        AppRoutes.map(
          viewer: MapViewer.company,
          customerLat: 37.5,
          customerLng: 32.25,
        ),
      );
      expect(uri.path, AppRoutes.mapBase);
      expect(uri.queryParameters, {
        'viewer': 'company',
        'lat': '37.5',
        'lng': '32.25',
      });
    });
  });
}

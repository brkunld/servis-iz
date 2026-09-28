import 'package:flutter_test/flutter_test.dart';
import 'package:mobil_proje/features/auth/domain/session.dart';
import 'package:mobil_proje/features/auth/domain/user_role.dart';

void main() {
  group('resolveSession', () {
    test('doğrulanmamış müşteri doğrulama ekranına gider', () {
      final s = resolveSession(
        uid: 'u',
        emailVerified: false,
        role: UserRole.customer,
      );
      expect(s, isA<VerificationRequired>());
    });

    test('rolü henüz yazılmamış yeni kayıt da doğrulama bekler', () {
      final s = resolveSession(uid: 'u', emailVerified: false, role: null);
      expect(s, isA<VerificationRequired>());
    });

    test('doğrulanmış ama rolü olmayan hesap geçersizdir', () {
      final s = resolveSession(uid: 'u', emailVerified: true, role: null);
      expect(s, isA<InvalidSession>());
      expect((s as InvalidSession).problem, SessionProblem.noRole);
    });

    test('şirket ve teknisyen için doğrulama gerekmez', () {
      for (final role in [UserRole.company, UserRole.technician]) {
        final s = resolveSession(uid: 'u', emailVerified: false, role: role);
        expect(s, isA<SignedIn>());
        expect((s as SignedIn).role, role);
      }
    });

    test('doğrulanmış müşteri giriş yapar', () {
      final s = resolveSession(
        uid: 'u',
        emailVerified: true,
        role: UserRole.customer,
      );
      expect(s, isA<SignedIn>());
    });
  });
}

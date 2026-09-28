import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum UserRole { customer, technician, company }

/// Kullanıcının rolünü, kaydının bulunduğu koleksiyondan bulur.
/// Sıra firestore.rules içindeki role() ile aynıdır.
///
/// Kayıttan hemen sonra müşteri belgesi henüz yazılmamış olabilir; bu yüzden
/// rol bulunamazsa birkaç kez kısa aralıklarla tekrar denenir.
Future<UserRole?> findUserRole(String uid, {int retries = 3}) async {
  final db = FirebaseFirestore.instance;
  const collections = {
    'customers': UserRole.customer,
    'technicians': UserRole.technician,
    'companies': UserRole.company,
  };

  for (var attempt = 0; attempt <= retries; attempt++) {
    for (final entry in collections.entries) {
      final doc = await db.collection(entry.key).doc(uid).get();
      if (doc.exists) return entry.value;
    }
    if (attempt < retries) {
      await Future.delayed(const Duration(milliseconds: 700));
    }
  }
  return null;
}

/// Müşteriler kendi kendine kayıt olduğu için e-posta doğrulaması zorunludur.
/// Şirket ve teknisyen hesaplarını güvenilir taraflar açar.
///
/// Rol henüz bulunamadıysa (kayıt yeni yapıldı, müşteri belgesi yazılıyor)
/// kullanıcı da doğrulama bekleyen müşteri sayılır.
bool needsEmailVerification(User user, UserRole? role) =>
    (role == null || role == UserRole.customer) && !user.emailVerified;

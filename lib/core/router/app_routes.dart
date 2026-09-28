import 'package:mobil_proje/features/auth/domain/user_role.dart';

/// Uygulamadaki bütün adresler (path) tek yerde.
///
/// Ekranlar birbirini doğrudan `Navigator.push(MaterialPageRoute(...))` ile
/// açmaz; `context.go(AppRoutes.x)` ya da `context.push(...)` ile adrese
/// gider. Hangi rolün hangi adrese girebileceği de burada tanımlıdır.
abstract final class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const register = '/login/register';
  static const verifyEmail = '/verify-email';

  static const customer = '/customer';
  static const newRequest = '/customer/new-request';
  static const pickLocation = '/customer/new-request/pick-location';

  static const technician = '/technician';

  static const company = '/company';
  static const addTechnician = '/company/technicians/new';
  static String editTechnician(String id) => '/company/technicians/$id/edit';

  static const chatBase = '/chat';
  static const mapBase = '/map';

  /// Sohbet: müşteri ile teknisyen arasında, talebe bağlı.
  static String chat({
    required String requestId,
    required String customerId,
    required String technicianId,
  }) => Uri(
    path: '$chatBase/$requestId',
    queryParameters: {'customer': customerId, 'technician': technicianId},
  ).toString();

  /// Harita: müşteri adresi ve teknisyenin canlı konumu.
  static String map({
    required MapViewer viewer,
    String? technicianId,
    String? customerId,
    double? customerLat,
    double? customerLng,
  }) => Uri(
    path: mapBase,
    queryParameters: {
      'viewer': viewer.name,
      if (technicianId != null) 'technician': technicianId,
      if (customerId != null) 'customer': customerId,
      if (customerLat != null) 'lat': '$customerLat',
      if (customerLng != null) 'lng': '$customerLng',
    },
  ).toString();

  /// Rolün ana ekranı.
  static String homeFor(UserRole role) => switch (role) {
    UserRole.customer => customer,
    UserRole.technician => technician,
    UserRole.company => company,
  };

  /// Rolün girebileceği adreslerin başları. Rol başka bir role ait adrese
  /// gitmeye çalışırsa kendi ana ekranına yönlendirilir.
  static List<String> allowedPrefixes(UserRole role) => switch (role) {
    UserRole.customer => [customer, chatBase, mapBase],
    UserRole.technician => [technician, chatBase, mapBase],
    UserRole.company => [company, mapBase],
  };
}

/// Haritayı kimin açtığı (başlık ve davranış buna göre değişir).
enum MapViewer { customer, technician, company }

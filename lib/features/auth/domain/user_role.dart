/// Kullanıcının rolü. Rol, kullanıcının kaydının hangi koleksiyonda
/// (`customers`, `technicians`, `companies`) bulunduğuna göre belirlenir;
/// bulma işi `AuthRepository.findUserRole` içindedir.
enum UserRole { customer, technician, company }

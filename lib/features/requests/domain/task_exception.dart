/// Bir talep işlemi (görev alma, puanlama...) yapılamadığında kullanıcıya
/// gösterilecek mesajı taşır.
class TaskException implements Exception {
  const TaskException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Servis talebinin yaşam döngüsü: pending → inProgress → completed.
///
/// [value] Firestore'da saklanan değerdir; mevcut veri ve firestore.rules
/// bu değerlere bağlı olduğu için değiştirilmemelidir.
enum RequestStatus {
  pending('Bekliyor'),
  inProgress('Devam Ediyor'),
  completed('Tamamlandı');

  const RequestStatus(this.value);

  final String value;

  /// Bilinmeyen ya da boş değer bekleyen talep sayılır.
  static RequestStatus fromValue(Object? value) => RequestStatus.values
      .firstWhere((s) => s.value == value, orElse: () => RequestStatus.pending);
}

/// Servis talebinin durum makinesi.
///
/// ```text
///   Bekliyor ──ata──▶ Devam Ediyor ──tamamla──▶ Tamamlandı
///   (pending)         (inProgress)              (completed)
/// ```
///
/// Geriye dönüş ya da adım atlama yoktur. Aynı kurallar sunucuda
/// `firestore.rules` içinde de uygulanır; burası uygulamanın, bir düğmeyi
/// göstermeden ya da bir yazma isteği göndermeden önce sorduğu yerdir.
///
/// [value] Firestore'da saklanan değerdir; mevcut veri ve firestore.rules
/// bu Türkçe değerlere bağlı olduğu için değiştirilmemelidir.
enum RequestStatus {
  pending('Bekliyor'),
  inProgress('Devam Ediyor'),
  completed('Tamamlandı');

  const RequestStatus(this.value);

  final String value;

  /// Bilinmeyen ya da boş değer bekleyen talep sayılır (ekranda gösterim
  /// için). Yazma kararlarında [tryFromValue] kullanılır.
  static RequestStatus fromValue(Object? value) =>
      tryFromValue(value) ?? RequestStatus.pending;

  /// Değer tanınmıyorsa null döner.
  static RequestStatus? tryFromValue(Object? value) {
    for (final status in RequestStatus.values) {
      if (status.value == value) return status;
    }
    return null;
  }

  /// İzin verilen geçişler: yalnız bir sonraki adıma.
  bool canTransitionTo(RequestStatus next) => switch ((this, next)) {
    (RequestStatus.pending, RequestStatus.inProgress) => true,
    (RequestStatus.inProgress, RequestStatus.completed) => true,
    _ => false,
  };

  /// Talep hâlâ açık mı (tamamlanmadı mı)?
  bool get isOpen => this != RequestStatus.completed;

  /// Teknisyen atanabilir mi (şirket ya da teknisyenin kendisi)?
  bool get canBeAssigned => canTransitionTo(RequestStatus.inProgress);

  /// Teknisyen görevi tamamlayabilir mi?
  bool get canBeCompleted => canTransitionTo(RequestStatus.completed);

  /// Teknisyen kullanılan parça ekleyip çıkarabilir mi?
  bool get canEditParts => this == RequestStatus.inProgress;

  /// Müşteri talebi silebilir mi? (Yalnız kimse işe başlamadan.)
  bool get canBeDeletedByCustomer => this == RequestStatus.pending;

  /// Müşteri teknisyenin konumunu haritada izleyebilir mi?
  bool get canTrackTechnician => this == RequestStatus.inProgress;

  /// Müşteri hizmeti puanlayabilir mi? (Ayrıca talep daha önce
  /// puanlanmamış olmalı; bkz. `ServiceRequest.canBeRated`.)
  bool get allowsRating => this == RequestStatus.completed;
}

/// Durum makinesinin izin vermediği bir işlem denendiğinde fırlatılır.
class InvalidTransitionException implements Exception {
  const InvalidTransitionException(this.from, this.to);

  final RequestStatus from;
  final RequestStatus to;

  @override
  String toString() =>
      'Talep "${from.value}" durumundan "${to.value}" durumuna geçemez.';
}

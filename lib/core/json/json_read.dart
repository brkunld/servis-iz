import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore'dan gelen `Map<String, dynamic>` verisini tip güvenli okumak için
/// küçük yardımcılar.
///
/// Firestore belgeleri şemasızdır: bir alan hiç olmayabilir, `null` olabilir
/// ya da beklenenden farklı tipte gelebilir (ör. `4` yerine `4.0`). Bu
/// fonksiyonlar `as` ile zorla dönüştürmek yerine tipi kontrol eder; böylece
/// bozuk bir belge uygulamayı çökertmez. `strict-casts` açıkken örtük
/// `dynamic` dönüşümü derleme hatası verdiği için model sınıfları veriyi
/// yalnız bu yardımcılarla okur.
typedef Json = Map<String, Object?>;

String? readString(Json json, String key) {
  final value = json[key];
  if (value == null) return null;
  return value is String ? value : value.toString();
}

int? readInt(Json json, String key) {
  final value = json[key];
  return value is num ? value.toInt() : null;
}

num? readNum(Json json, String key) {
  final value = json[key];
  return value is num ? value : null;
}

bool? readBool(Json json, String key) {
  final value = json[key];
  return value is bool ? value : null;
}

/// Firestore `Timestamp` değerini `DateTime`'a çevirir.
/// `FieldValue.serverTimestamp()` ile yazılan alan, sunucu onaylayana kadar
/// yerel önbellekte `null` görünür; bu durumda da `null` döner.
DateTime? readDateTime(Json json, String key) {
  final value = json[key];
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

List<String> readStringList(Json json, String key) {
  final value = json[key];
  if (value is! List) return const [];
  return List.unmodifiable(value.map((e) => e.toString()));
}

Json? readMap(Json json, String key) => asJson(json[key]);

/// Bilinmeyen bir değeri `Map<String, Object?>` olarak döndürür (değilse null).
Json? asJson(Object? value) {
  if (value is! Map) return null;
  return value.map((k, v) => MapEntry(k.toString(), v));
}

/// `DateTime`'ı Firestore'a yazılacak `Timestamp`'e çevirir.
Timestamp? toTimestamp(DateTime? date) =>
    date == null ? null : Timestamp.fromDate(date);

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:mobil_proje/core/json/coordinates.dart';
import 'package:mobil_proje/core/json/json_read.dart';

/// `technicians/{uid}` belgesindeki teknisyen. Belge adı, teknisyenin
/// Firebase Auth kullanıcı kimliğidir (uid).
@immutable
class Technician {
  const Technician({
    required this.id,
    this.name,
    this.email,
    this.phone,
    this.rating,
    this.ratingCount = 0,
    this.totalStars = 0,
    this.active = true,
    this.isAvailable = true,
    this.location,
    this.createdAt,
    this.completedJobs,
  });

  final String id;
  final String? name;
  final String? email;
  final String? phone;

  /// Ortalama puan. Eski kayıtlarda tam sayı (ör. `0`) da olabilir; ekranda
  /// aynen gösterildiği için `num` tutulur.
  final num? rating;
  final int ratingCount;
  final int totalStars;

  /// Şirket teknisyeni devre dışı bıraktığında false olur. Alan yoksa aktif
  /// sayılır.
  final bool active;

  /// Devam eden bir görevi yoksa true. Alan yoksa müsait sayılır.
  final bool isAvailable;

  /// Teknisyenin son bilinen konumu (uygulama açıkken güncellenir).
  final Coordinates? location;
  final DateTime? createdAt;
  final int? completedJobs;

  factory Technician.fromJson(String id, Json json) => Technician(
    id: id,
    name: readString(json, 'name'),
    email: readString(json, 'email'),
    phone: readString(json, 'phone'),
    rating: readNum(json, 'rating'),
    ratingCount: readInt(json, 'ratingCount') ?? 0,
    totalStars: readInt(json, 'totalStars') ?? 0,
    active: readBool(json, 'active') ?? true,
    isAvailable: readBool(json, 'isAvailable') ?? true,
    location: Coordinates.tryParse(json['location']),
    createdAt: readDateTime(json, 'createdAt'),
    completedJobs: readInt(json, 'completedJobs'),
  );

  Json toJson() => {
    'name': name,
    'email': email,
    'phone': phone,
    'rating': rating,
    'ratingCount': ratingCount,
    'totalStars': totalStars,
    'active': active,
    'isAvailable': isAvailable,
    'location': location?.toJson(),
    'createdAt': toTimestamp(createdAt),
    if (completedJobs != null) 'completedJobs': completedJobs,
  };

  /// Şirketin yeni teknisyen eklerken yazdığı ilk belge.
  static Json createJson({
    required String name,
    required String email,
    required String phone,
  }) => {
    'name': name,
    'email': email,
    'phone': phone,
    'rating': 0.0,
    'ratingCount': 0,
    'totalStars': 0,
    'active': true,
    'location': null,
    'isAvailable': true,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

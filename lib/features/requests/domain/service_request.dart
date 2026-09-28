import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:mobil_proje/core/json/coordinates.dart';
import 'package:mobil_proje/core/json/json_read.dart';
import 'request_status.dart';

/// `requests/{id}` belgesindeki servis talebi.
///
/// Değişmez (immutable) bir sınıftır: alanlar `final`, değişiklik Firestore'a
/// yazılır ve yeni hâli akıştan (stream) yeni bir nesne olarak gelir.
///
/// Firestore alan adları değişmedi; Türkçe alanlar Dart'ta İngilizce adla
/// tutulur: `kat` → [floor], `daire` → [apartment], `name` → [customerName].
@immutable
class ServiceRequest {
  const ServiceRequest({
    required this.id,
    required this.customerId,
    required this.status,
    this.technicianId,
    this.customerName,
    this.phone,
    this.email,
    this.address,
    this.issue,
    this.floor,
    this.apartment,
    this.city,
    this.district,
    this.location,
    this.createdAt,
    this.updatedAt,
    this.completedAt,
    this.rated = false,
    this.givenStars,
    this.comment,
    this.usedParts = const [],
  });

  final String id;
  final String customerId;
  final String? technicianId;
  final RequestStatus status;

  final String? customerName;
  final String? phone;
  final String? email;
  final String? address;
  final String? issue;
  final String? floor;
  final String? apartment;
  final String? city;
  final String? district;
  final Coordinates? location;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  final bool rated;
  final int? givenStars;
  final String? comment;
  final List<String> usedParts;

  factory ServiceRequest.fromJson(String id, Json json) => ServiceRequest(
    id: id,
    customerId: readString(json, 'customerId') ?? '',
    technicianId: readString(json, 'technicianId'),
    status: RequestStatus.fromValue(json['status']),
    customerName: readString(json, 'name'),
    phone: readString(json, 'phone'),
    email: readString(json, 'email'),
    address: readString(json, 'address'),
    issue: readString(json, 'issue'),
    floor: readString(json, 'kat'),
    apartment: readString(json, 'daire'),
    city: readString(json, 'city'),
    district: readString(json, 'district'),
    location: Coordinates.tryParse(json['location']),
    createdAt: readDateTime(json, 'createdAt'),
    updatedAt: readDateTime(json, 'updatedAt'),
    completedAt: readDateTime(json, 'completedAt'),
    rated: readBool(json, 'rated') ?? false,
    givenStars: readInt(json, 'givenStars'),
    comment: readString(json, 'comment'),
    usedParts: readStringList(json, 'usedParts'),
  );

  /// Belgenin Firestore'daki biçimi (id belge adıdır, alanlara girmez).
  Json toJson() => {
    'customerId': customerId,
    'technicianId': technicianId,
    'status': status.value,
    'name': customerName,
    'phone': phone,
    'email': email,
    'address': address,
    'issue': issue,
    'kat': floor,
    'daire': apartment,
    'city': city,
    'district': district,
    'location': location?.toJson(),
    'createdAt': toTimestamp(createdAt),
    if (updatedAt != null) 'updatedAt': toTimestamp(updatedAt),
    if (completedAt != null) 'completedAt': toTimestamp(completedAt),
    'rated': rated,
    'givenStars': givenStars,
    'comment': comment,
    if (usedParts.isNotEmpty) 'usedParts': usedParts,
  };

  bool get isAssigned => technicianId != null;

  /// Müşteri puan verebilir mi? Tamamlanmış, puanlanmamış ve bir teknisyene
  /// atanmış olmalı (firestore.rules'taki koşulla aynı).
  bool get canBeRated => status.allowsRating && !rated && technicianId != null;
}

/// Müşterinin formdan oluşturduğu yeni talep (henüz id'si yok).
///
/// [toCreateJson] firestore.rules'taki `requests` create kuralına uyar:
/// durum "Bekliyor", `technicianId` açıkça null, `rated` false.
@immutable
class NewServiceRequest {
  const NewServiceRequest({
    required this.customerId,
    required this.customerName,
    required this.phone,
    required this.email,
    required this.address,
    required this.issue,
    required this.floor,
    required this.apartment,
    required this.city,
    required this.district,
    this.location,
  });

  final String customerId;
  final String customerName;
  final String phone;
  final String email;
  final String address;
  final String issue;
  final String floor;
  final String apartment;
  final String city;
  final String district;
  final Coordinates? location;

  Json toCreateJson() => {
    'customerId': customerId,
    'name': customerName,
    'phone': phone,
    'email': email,
    'address': address,
    'issue': issue,
    'kat': floor,
    'daire': apartment,
    'city': city,
    'district': district,
    'status': RequestStatus.pending.value,
    'createdAt': FieldValue.serverTimestamp(),
    'technicianId': null,
    'location': location?.toJson(),
    'rated': false,
    'givenStars': null,
    'comment': null,
  };
}

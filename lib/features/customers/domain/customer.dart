import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:mobil_proje/core/json/json_read.dart';

/// `customers/{uid}` belgesindeki müşteri.
@immutable
class Customer {
  const Customer({
    required this.id,
    this.name,
    this.email,
    this.phone,
    this.createdAt,
  });

  final String id;
  final String? name;
  final String? email;
  final String? phone;
  final DateTime? createdAt;

  factory Customer.fromJson(String id, Json json) => Customer(
    id: id,
    name: readString(json, 'name'),
    email: readString(json, 'email'),
    phone: readString(json, 'phone'),
    createdAt: readDateTime(json, 'createdAt'),
  );

  Json toJson() => {
    'name': name,
    'email': email,
    'phone': phone,
    'createdAt': toTimestamp(createdAt),
  };

  /// Kayıt sırasında yazılan belge. firestore.rules yalnız bu dört alana
  /// izin verir.
  static Json createJson({
    required String name,
    required String email,
    required String phone,
  }) => {
    'name': name,
    'email': email,
    'phone': phone,
    'createdAt': FieldValue.serverTimestamp(),
  };
}

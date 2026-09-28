import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'json_read.dart';

/// Enlem/boylam çifti. Firestore'da `{lat: .., lng: ..}` haritası olarak
/// saklanır; eski kayıtlarda `GeoPoint` de olabilir, ikisi de okunur.
@immutable
class Coordinates {
  const Coordinates(this.lat, this.lng);

  final double lat;
  final double lng;

  /// Değer okunamıyorsa (yoksa, lat/lng eksikse) null döner.
  static Coordinates? tryParse(Object? value) {
    if (value is GeoPoint) return Coordinates(value.latitude, value.longitude);

    final json = asJson(value);
    if (json == null) return null;
    final lat = readNum(json, 'lat');
    final lng = readNum(json, 'lng');
    if (lat == null || lng == null) return null;
    return Coordinates(lat.toDouble(), lng.toDouble());
  }

  Json toJson() => {'lat': lat, 'lng': lng};

  @override
  bool operator ==(Object other) =>
      other is Coordinates && other.lat == lat && other.lng == lng;

  @override
  int get hashCode => Object.hash(lat, lng);

  @override
  String toString() => 'Coordinates($lat, $lng)';
}

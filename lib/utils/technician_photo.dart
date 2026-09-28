import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Teknisyen profil fotoğrafları Firebase Storage yerine küçük bir JPEG
/// olarak Firestore'da, `technicianPhotos/{technicianId}` belgesinde tutulur.
/// Spark (ücretsiz) planında Storage kullanılamadığı için seçildi; yalnız
/// avatar boyutundaki görseller için uygundur.
const int _maxDimension = 256;
const int _jpegQuality = 70;

/// firestore.rules içindeki sınırla aynı olmalı.
const int maxPhotoBytes = 200 * 1024;

final Map<String, Uint8List?> _cache = {};

DocumentReference<Map<String, dynamic>> _photoDoc(String technicianId) =>
    FirebaseFirestore.instance.collection('technicianPhotos').doc(technicianId);

/// Galeriden fotoğraf seçer ve avatar boyutuna küçültür.
/// Kullanıcı vazgeçerse null döner.
Future<Uint8List?> pickTechnicianPhoto() async {
  final image = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: _maxDimension.toDouble(),
    maxHeight: _maxDimension.toDouble(),
    imageQuality: _jpegQuality,
  );
  if (image == null) return null;

  final bytes = await image.readAsBytes();
  if (bytes.length > maxPhotoBytes) {
    throw Exception('Fotoğraf çok büyük, başka bir fotoğraf seçin.');
  }
  return bytes;
}

Future<void> saveTechnicianPhoto(String technicianId, Uint8List bytes) async {
  await _photoDoc(
    technicianId,
  ).set({'data': Blob(bytes), 'updatedAt': FieldValue.serverTimestamp()});
  _cache[technicianId] = bytes;
}

/// Fotoğrafı yükler; aynı oturumda tekrar okumamak için bellekte tutar.
Future<Uint8List?> loadTechnicianPhoto(String technicianId) async {
  if (_cache.containsKey(technicianId)) return _cache[technicianId];

  final snap = await _photoDoc(technicianId).get();
  final data = snap.data()?['data'];
  final bytes = data is Blob ? data.bytes : null;
  _cache[technicianId] = bytes;
  return bytes;
}

/// Teknisyen fotoğrafını, yoksa varsayılan görseli gösteren avatar.
class TechnicianAvatar extends StatelessWidget {
  const TechnicianAvatar({
    super.key,
    required this.technicianId,
    this.radius = 25,
    this.backgroundColor,
    this.preview,
  });

  final String? technicianId;
  final double radius;
  final Color? backgroundColor;

  /// Henüz kaydedilmemiş, yeni seçilen fotoğraf (düzenleme ekranı için).
  final Uint8List? preview;

  static const _placeholder = AssetImage('assets/default_technician.jpg');

  @override
  Widget build(BuildContext context) {
    final id = technicianId;
    if (preview != null || id == null || id.isEmpty) {
      return _avatar(preview);
    }

    return FutureBuilder<Uint8List?>(
      future: loadTechnicianPhoto(id),
      builder: (context, snap) => _avatar(snap.data),
    );
  }

  Widget _avatar(Uint8List? bytes) => CircleAvatar(
    radius: radius,
    backgroundColor: backgroundColor ?? Colors.grey.shade200,
    backgroundImage: bytes != null ? MemoryImage(bytes) : _placeholder,
  );
}

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:mobil_proje/features/technicians/data/technician_providers.dart';
import 'package:mobil_proje/features/technicians/data/technician_repository.dart';

const int _maxDimension = 256;
const int _jpegQuality = 70;

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
  if (bytes.length > TechnicianPhotoRepository.maxPhotoBytes) {
    throw Exception('Fotoğraf çok büyük, başka bir fotoğraf seçin.');
  }
  return bytes;
}

/// Fotoğrafı kaydeder ve önbellekteki eski fotoğrafı geçersiz kılar.
Future<void> saveTechnicianPhoto(
  WidgetRef ref,
  String technicianId,
  Uint8List bytes,
) async {
  await ref.read(technicianPhotoRepositoryProvider).save(technicianId, bytes);
  ref.invalidate(technicianPhotoProvider(technicianId));
}

/// Teknisyen fotoğrafını, yoksa varsayılan görseli gösteren avatar.
class TechnicianAvatar extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final id = technicianId;
    if (preview != null || id == null || id.isEmpty) {
      return _avatar(preview);
    }

    // Yüklenirken ya da hata olursa varsayılan görsel gösterilir.
    final photo = ref.watch(technicianPhotoProvider(id)).valueOrNull;
    return _avatar(photo);
  }

  Widget _avatar(Uint8List? bytes) => CircleAvatar(
    radius: radius,
    backgroundColor: backgroundColor ?? Colors.grey.shade200,
    backgroundImage: bytes != null ? MemoryImage(bytes) : _placeholder,
  );
}

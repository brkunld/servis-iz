import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobil_proje/features/technicians/data/technician_repository.dart';
import 'package:mobil_proje/features/technicians/domain/technician.dart';

/// Aktif teknisyenler (şirket paneli).
final activeTechniciansProvider = StreamProvider.autoDispose<List<Technician>>(
  (ref) => ref.watch(technicianRepositoryProvider).watchActive(),
);

/// Devre dışı teknisyenler.
final inactiveTechniciansProvider =
    StreamProvider.autoDispose<List<Technician>>(
      (ref) => ref.watch(technicianRepositoryProvider).watchInactive(),
    );

/// Atanabilir (aktif ve boşta) teknisyenler.
final availableTechniciansProvider =
    StreamProvider.autoDispose<List<Technician>>(
      (ref) => ref.watch(technicianRepositoryProvider).watchAvailable(),
    );

/// Tek teknisyen, bir kez okunur (müşterinin talep kartı, düzenleme ekranı).
final technicianProvider = FutureProvider.autoDispose
    .family<Technician?, String>(
      (ref, id) => ref.watch(technicianRepositoryProvider).getTechnician(id),
    );

/// Tek teknisyen, canlı (harita takip ekranı).
final technicianStreamProvider = StreamProvider.autoDispose
    .family<Technician?, String>(
      (ref, id) => ref.watch(technicianRepositoryProvider).watchTechnician(id),
    );

/// Teknisyen fotoğrafı. `autoDispose` değildir: bir kez yüklenen fotoğraf
/// oturum boyunca bellekte kalır (eski elle yazılmış önbelleğin yerine).
/// Fotoğraf değişince `ref.invalidate(technicianPhotoProvider(id))`.
final technicianPhotoProvider = FutureProvider.family<Uint8List?, String>(
  (ref, id) => ref.watch(technicianPhotoRepositoryProvider).load(id),
);

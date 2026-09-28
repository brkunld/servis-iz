import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobil_proje/core/router/app_routes.dart';
import 'package:mobil_proje/features/requests/data/request_providers.dart';
import 'package:mobil_proje/features/requests/domain/request_status.dart';
import 'package:mobil_proje/features/requests/domain/service_request.dart';
import 'package:mobil_proje/features/technicians/data/technician_providers.dart';
import 'package:mobil_proje/features/technicians/domain/technician.dart';
import 'package:mobil_proje/features/technicians/presentation/technician_avatar.dart';

/// Şirket panelinin "Teknisyenler" sekmesi: aktif teknisyenler, her birinin
/// boşta mı görevde mi olduğu.
class TechniciansTab extends ConsumerWidget {
  const TechniciansTab({
    super.key,
    required this.onShowDetails,
    required this.onDisable,
  });

  final void Function(Technician technician) onShowDetails;
  final void Function(Technician technician) onDisable;

  /// Teknisyenin tamamlanmamış talebi (varsa).
  static ServiceRequest? openRequestOf(
    String technicianId,
    List<ServiceRequest> requests,
  ) {
    for (final r in requests) {
      if (r.technicianId == technicianId && r.status.isOpen) return r;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final techs = ref.watch(activeTechniciansProvider).valueOrNull;
    if (techs == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (techs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.engineering_outlined,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              "Henüz teknisyen eklenmedi",
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    final requests = ref.watch(allRequestsProvider).valueOrNull;
    if (requests == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      children: [
        for (final tech in techs)
          TechnicianCard(
            technician: tech,
            openRequest: openRequestOf(tech.id, requests),
            onShowDetails: () => onShowDetails(tech),
            onDisable: () => onDisable(tech),
          ),
      ],
    );
  }
}

/// Tek teknisyen kartı: fotoğraf, durum, İzle / Detay / Düzenle / Devre dışı.
class TechnicianCard extends StatelessWidget {
  const TechnicianCard({
    super.key,
    required this.technician,
    required this.openRequest,
    required this.onShowDetails,
    required this.onDisable,
  });

  final Technician technician;

  /// Teknisyenin devam eden işi; yoksa boştadır.
  final ServiceRequest? openRequest;
  final VoidCallback onShowDetails;
  final VoidCallback onDisable;

  @override
  Widget build(BuildContext context) {
    final isAssigned = openRequest != null;
    final customerLoc = openRequest?.location;
    final hasOwnLocation = technician.location != null;
    final status = isAssigned ? RequestStatus.inProgress.value : "Boşta";

    final accent = isAssigned ? Colors.blue : Colors.green;

    return Card(
      elevation: 3,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: accent, width: 3),
                    ),
                    child: TechnicianAvatar(technicianId: technician.id),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          technician.name ?? "Teknisyen",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: accent.shade100,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accent.shade300, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: accent.shade700,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          status,
                          style: TextStyle(
                            color: accent.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: customerLoc == null
                          ? null
                          : () => context.push(
                              AppRoutes.map(
                                viewer: MapViewer.company,
                                technicianId: technician.id,
                                customerId: openRequest?.customerId,
                                customerLat: customerLoc.lat,
                                customerLng: customerLoc.lng,
                              ),
                            ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade500,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: hasOwnLocation ? 3 : 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(
                        hasOwnLocation
                            ? Icons.map_outlined
                            : Icons.location_off,
                        size: 20,
                      ),
                      label: const Text(
                        "İzle",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onShowDetails,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue.shade700,
                        side: BorderSide(
                          color: Colors.blue.shade600,
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Icon(Icons.info_outline, size: 18),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          context.push(AppRoutes.editTechnician(technician.id)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Icon(Icons.edit, size: 20),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: isAssigned ? null : onDisable,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isAssigned
                          ? Colors.grey.shade400
                          : Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      minimumSize: const Size(45, 45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: isAssigned ? 0 : 2,
                    ),
                    child: Icon(
                      Icons.person_off,
                      size: 22,
                      color: isAssigned ? Colors.white70 : Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
            ],
          ),
        ),
      ),
    );
  }
}

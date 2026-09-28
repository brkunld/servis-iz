import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobil_proje/core/router/app_routes.dart';
import 'package:mobil_proje/features/company/presentation/widgets/status_chip.dart';
import 'package:mobil_proje/features/customers/domain/customer.dart';
import 'package:mobil_proje/features/requests/data/request_providers.dart';
import 'package:mobil_proje/features/requests/domain/service_request.dart';

/// Müşterinin taleplerini alt sayfada (bottom sheet) gösterir. Bekleyen
/// talep için "Ata" düğmesi [onAssign]'ı çağırır.
Future<void> showCustomerRequestsSheet(
  BuildContext context, {
  required Customer customer,
  required void Function(ServiceRequest request) onAssign,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) =>
        _CustomerRequestsSheet(customer: customer, onAssign: onAssign),
  );
}

class _CustomerRequestsSheet extends ConsumerWidget {
  const _CustomerRequestsSheet({
    required this.customer,
    required this.onAssign,
  });

  final Customer customer;
  final void Function(ServiceRequest request) onAssign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(customerRequestsProvider(customer.id));

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SheetHandle(),
          _header(context),
          Divider(height: 1, color: Colors.grey.shade300),
          Expanded(
            child: requestsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text("Talepler yüklenemedi: $e")),
              data: (requests) {
                if (requests.isEmpty) return const _NoRequests();

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: requests.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) => _AnimatedRequestTile(
                    index: index,
                    request: requests[index],
                    onAssign: () {
                      Navigator.pop(context);
                      onAssign(requests[index]);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Hero(
            tag: 'customer_avatar_${customer.id}',
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade600,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name ?? "Müşteri",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[900],
                  ),
                ),
                Text(
                  "Müşteri İstekleri",
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
            style: IconButton.styleFrom(backgroundColor: Colors.grey.shade100),
          ),
        ],
      ),
    );
  }
}

class _NoRequests extends StatelessWidget {
  const _NoRequests();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.assignment_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "İstek yok",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Bu müşterinin henüz isteği bulunmuyor",
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

/// Talep kartı; liste açılırken sırayla kayarak belirir.
class _AnimatedRequestTile extends StatelessWidget {
  const _AnimatedRequestTile({
    required this.index,
    required this.request,
    required this.onAssign,
  });

  final int index;
  final ServiceRequest request;
  final VoidCallback onAssign;

  static String formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return "Bugün ${date.hour}:${date.minute.toString().padLeft(2, '0')}";
    } else if (difference.inDays == 1) {
      return "Dün";
    } else if (difference.inDays < 7) {
      return "${difference.inDays} gün önce";
    } else {
      return "${date.day}/${date.month}/${date.year}";
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = request.location;
    final createdAt = request.createdAt;
    final canAssign = request.status.canBeAssigned;

    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 80)),
      curve: Curves.easeOutCubic,
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, 15 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StatusChip(status: request.status.value),
                  const Spacer(),
                  if (createdAt != null)
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formatDate(createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.build_circle_outlined,
                      color: Colors.orange.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        request.issue ?? "Belirtilmedi",
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: location == null
                          ? null
                          : () => context.push(
                              AppRoutes.map(
                                viewer: MapViewer.company,
                                technicianId: request.technicianId,
                                customerId: request.customerId,
                                customerLat: location.lat,
                                customerLng: location.lng,
                              ),
                            ),
                      style: _actionStyle(
                        enabled: location != null,
                        color: Colors.blue.shade600,
                      ),
                      icon: Icon(
                        location != null
                            ? Icons.map_rounded
                            : Icons.location_off_rounded,
                        size: 18,
                      ),
                      label: const Text(
                        "Harita",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: canAssign ? onAssign : null,
                      style: _actionStyle(
                        enabled: canAssign,
                        color: Colors.green.shade600,
                      ),
                      icon: const Icon(Icons.engineering_rounded, size: 18),
                      label: const Text(
                        "Ata",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  ButtonStyle _actionStyle({required bool enabled, required Color color}) =>
      ElevatedButton.styleFrom(
        backgroundColor: enabled ? color : Colors.grey.shade300,
        foregroundColor: enabled ? Colors.white : Colors.grey.shade600,
        padding: const EdgeInsets.symmetric(vertical: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      );
}

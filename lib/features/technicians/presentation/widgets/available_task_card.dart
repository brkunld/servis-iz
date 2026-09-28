import 'package:flutter/material.dart';

import 'package:mobil_proje/features/requests/domain/service_request.dart';
import 'package:mobil_proje/features/technicians/presentation/widgets/task_info_row.dart';

/// Teknisyenin alabileceği bekleyen görev kartı.
class AvailableTaskCard extends StatelessWidget {
  const AvailableTaskCard({
    super.key,
    required this.request,
    required this.isExpanded,
    required this.onToggle,
    required this.onTake,
    required this.onOpenMap,
    required this.onChat,
  });

  final ServiceRequest request;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onTake;
  final VoidCallback onOpenMap;
  final VoidCallback onChat;

  @override
  Widget build(BuildContext context) {
    final issue = request.issue ?? "Arıza belirsiz";
    final city = request.city ?? "-";
    final district = request.district ?? "-";

    return Card(
      elevation: isExpanded ? 4 : 2,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.build_circle,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          issue,
                          maxLines: isExpanded ? null : 2,
                          overflow: isExpanded
                              ? TextOverflow.visible
                              : TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 16,
                              color: Colors.blue.shade600,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                "$city / $district",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.blue.shade600,
                    size: 28,
                  ),
                ],
              ),

              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  children: [
                    const SizedBox(height: 16),
                    Divider(color: Colors.grey.shade300),
                    const SizedBox(height: 16),
                    TaskInfoRow(
                      icon: Icons.person_outline,
                      label: "Müşteri",
                      value: request.customerName ?? "İsimsiz",
                    ),
                    const SizedBox(height: 12),
                    TaskInfoRow(
                      icon: Icons.phone_outlined,
                      label: "Telefon",
                      value: request.phone ?? "Telefon yok",
                    ),
                    const SizedBox(height: 12),
                    TaskInfoRow(
                      icon: Icons.home_outlined,
                      label: "Adres",
                      value: request.address ?? "Adres belirtilmemiş",
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onOpenMap,
                        icon: Icon(
                          Icons.map_outlined,
                          color: Colors.blue.shade700,
                        ),
                        label: Text(
                          "Haritada Göster",
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                crossFadeState: isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 300),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: onTake,
                      icon: const Icon(Icons.check_circle_outline, size: 20),
                      label: const Text("Görevi Al"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: onChat,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.blue.shade700,
                        elevation: 0,
                        side: BorderSide(
                          color: Colors.blue.shade300,
                          width: 1.5,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Icon(Icons.chat_bubble_outline),
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
}

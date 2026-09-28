import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobil_proje/features/requests/domain/request_status.dart';
import 'package:mobil_proje/features/requests/domain/service_request.dart';
import 'package:mobil_proje/features/technicians/data/technician_providers.dart';
import 'package:mobil_proje/features/technicians/presentation/technician_avatar.dart';

/// Müşterinin talep listesindeki tek kart. Kart yalnız gösterir; işlemler
/// (sil, puanla, sohbet, harita) ekrana geri çağrı (callback) olarak verilir.
/// Hangi düğmenin görüneceğine durum makinesi karar verir.
class CustomerRequestCard extends StatelessWidget {
  const CustomerRequestCard({
    super.key,
    required this.request,
    required this.isExpanded,
    required this.selectedStars,
    required this.commentController,
    required this.onToggle,
    required this.onStarSelected,
    required this.onChat,
    required this.onOpenMap,
    required this.onDelete,
    required this.onRate,
  });

  final ServiceRequest request;
  final bool isExpanded;
  final int selectedStars;
  final TextEditingController commentController;
  final VoidCallback onToggle;
  final ValueChanged<int> onStarSelected;
  final VoidCallback onChat;
  final VoidCallback onOpenMap;
  final VoidCallback onDelete;
  final VoidCallback onRate;

  static Color statusColor(RequestStatus status) => switch (status) {
    RequestStatus.pending => Colors.green.shade300,
    RequestStatus.inProgress => Colors.orange.shade200,
    RequestStatus.completed => Colors.green,
  };

  static String _formatDate(DateTime? d) => d == null
      ? "Tarih yok"
      : "${d.day}/${d.month}/${d.year} ${d.hour}:${d.minute.toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    final status = request.status;
    final address = request.address ?? "Adres belirtilmemiş";

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                _header(status),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: isExpanded
                        ? _expandedBody(address)
                        : _collapsedBody(address),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(RequestStatus status) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor(status).withValues(alpha: 0.2),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.issue ?? "Bildirilmedi",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(request.createdAt),
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor(status),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status.value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _collapsedBody(String address) => [
    Row(
      children: [
        Icon(Icons.location_on_outlined, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            address,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
    const SizedBox(height: 12),
    Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Detaylar için tıklayın",
            style: TextStyle(
              color: Colors.blue.shade700,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.blue.shade700,
            size: 20,
          ),
        ],
      ),
    ),
  ];

  List<Widget> _expandedBody(String address) {
    final technicianId = request.technicianId;

    return [
      _InfoRow(icon: Icons.location_on, label: "Adres", value: address),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _InfoRow(
              icon: Icons.stairs,
              label: "Kat",
              value: request.floor ?? "-",
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _InfoRow(
              icon: Icons.door_front_door,
              label: "Daire",
              value: request.apartment ?? "-",
            ),
          ),
        ],
      ),

      if (technicianId != null) ...[
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 16),
        _AssignedTechnicianPanel(
          technicianId: technicianId,
          showMapButton:
              request.status.canTrackTechnician && request.location != null,
          onChat: onChat,
          onOpenMap: onOpenMap,
        ),
      ],

      const SizedBox(height: 16),

      if (request.status.canBeDeletedByCustomer)
        ElevatedButton.icon(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
          label: const Text("Talebi Sil"),
          style: _wideButton(Colors.red),
        ),

      if (request.canBeRated) ...[
        const SizedBox(height: 20),
        _RatingPanel(
          selectedStars: selectedStars,
          commentController: commentController,
          onStarSelected: onStarSelected,
          onSubmit: onRate,
        ),
      ],

      const SizedBox(height: 12),

      Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Kapat",
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_up_rounded,
              color: Colors.grey.shade600,
              size: 20,
            ),
          ],
        ),
      ),
    ];
  }
}

ButtonStyle _wideButton(Color color) => ElevatedButton.styleFrom(
  backgroundColor: color,
  foregroundColor: Colors.white,
  minimumSize: const Size(double.infinity, 50),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
);

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Atanan teknisyenin adı, telefonu, fotoğrafı; sohbet ve harita düğmeleri.
class _AssignedTechnicianPanel extends ConsumerWidget {
  const _AssignedTechnicianPanel({
    required this.technicianId,
    required this.showMapButton,
    required this.onChat,
    required this.onOpenMap,
  });

  final String technicianId;
  final bool showMapButton;
  final VoidCallback onChat;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final techAsync = ref.watch(technicianProvider(technicianId));
    if (!techAsync.hasValue) {
      return const Center(child: CircularProgressIndicator());
    }
    final tech = techAsync.value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blue, width: 3),
                ),
                child: TechnicianAvatar(technicianId: technicianId, radius: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Atanan Teknisyen",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tech?.name ?? "Teknisyen",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.phone,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          tech?.phone ?? "",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onChat,
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text("Mesajlaş"),
            style: _wideButton(Colors.deepPurple),
          ),
          if (showMapButton) ...[
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onOpenMap,
              icon: const Icon(Icons.map_outlined),
              label: const Text("Haritada Gör"),
              style: _wideButton(Colors.blue),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tamamlanan talep için yıldız + yorum formu.
class _RatingPanel extends StatelessWidget {
  const _RatingPanel({
    required this.selectedStars,
    required this.commentController,
    required this.onStarSelected,
    required this.onSubmit,
  });

  final int selectedStars;
  final TextEditingController commentController;
  final ValueChanged<int> onStarSelected;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final canSubmit = selectedStars > 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.amber.shade50, Colors.amber.shade100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade300, width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.star, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                "Hizmeti Değerlendir",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (i) {
              final starIndex = i + 1;
              final filled = starIndex <= selectedStars;

              return IconButton(
                onPressed: () => onStarSelected(starIndex),
                icon: Icon(
                  filled ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: filled ? Colors.amber : Colors.grey.shade400,
                  size: 40,
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: commentController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: "Yorumunuzu yazın (isteğe bağlı)",
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.amber.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.amber.shade600, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: canSubmit ? onSubmit : null,
            icon: const Icon(Icons.send_rounded),
            label: const Text("Gönder"),
            style: _wideButton(canSubmit ? Colors.green : Colors.grey),
          ),
        ],
      ),
    );
  }
}

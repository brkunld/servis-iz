import 'package:flutter/material.dart';

import 'package:mobil_proje/features/requests/domain/request_status.dart';
import 'package:mobil_proje/features/requests/domain/service_request.dart';

/// Teknisyenin devam eden görevi: arıza, adres, harita, sohbet, kullanılan
/// parçalar ve "Görevi Tamamla".
class ActiveTaskCard extends StatelessWidget {
  const ActiveTaskCard({
    super.key,
    required this.request,
    required this.partController,
    required this.loading,
    required this.onOpenMap,
    required this.onChat,
    required this.onAddPart,
    required this.onRemovePart,
    required this.onComplete,
  });

  final ServiceRequest request;
  final TextEditingController partController;
  final bool loading;
  final VoidCallback onOpenMap;
  final VoidCallback onChat;
  final VoidCallback onAddPart;
  final ValueChanged<String> onRemovePart;
  final VoidCallback onComplete;

  static Color statusColor(RequestStatus status) => switch (status) {
    RequestStatus.pending => Colors.blue.shade100,
    RequestStatus.inProgress => Colors.blue.shade300,
    RequestStatus.completed => Colors.blue.shade400,
  };

  @override
  Widget build(BuildContext context) {
    final canComplete = request.status.canBeCompleted;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            const SizedBox(height: 20),
            _details(),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onOpenMap,
                icon: const Icon(Icons.map_outlined, color: Colors.blueAccent),
                label: const Text(
                  "Haritada Göster",
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onChat,
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text(
                  "Müşteri ile Mesajlaş",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            ..._parts(),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: loading || !canComplete ? null : onComplete,
                icon: loading
                    ? const SizedBox.shrink()
                    : const Icon(Icons.check_circle, size: 22),
                label: loading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                          SizedBox(width: 12),
                          Text("İşleniyor..."),
                        ],
                      )
                    : const Text(
                        "Görevi Tamamla",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade600],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.assignment,
                color: Colors.white,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              "Aktif Görev",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: statusColor(request.status),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            request.status.value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _details() {
    Widget label(IconData icon, String text) => Row(
      children: [
        Icon(icon, color: Colors.blue.shade700, size: 20),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );

    Widget value(String text) => Padding(
      padding: const EdgeInsets.only(left: 28),
      child: Text(
        text,
        style: TextStyle(fontSize: 15, color: Colors.grey.shade800),
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          label(Icons.error_outline, "Arıza:"),
          const SizedBox(height: 16),
          value(request.issue ?? ""),
          const SizedBox(height: 12),
          label(Icons.location_on_outlined, "Adres:"),
          const SizedBox(height: 4),
          value(request.address ?? ""),
        ],
      ),
    );
  }

  List<Widget> _parts() {
    final usedParts = request.usedParts;

    return [
      Row(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            color: Colors.blue.shade700,
            size: 22,
          ),
          const SizedBox(width: 8),
          const Text(
            "Kullanılan Parçalar",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),

      const SizedBox(height: 12),

      if (usedParts.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            "Henüz parça eklenmedi.",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
        ),
      for (final part in usedParts)
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.blue.shade200),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                Icons.build_circle_outlined,
                color: Colors.blue.shade600,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(part, style: const TextStyle(fontSize: 15))),
              IconButton(
                icon: const Icon(Icons.clear, color: Colors.red),
                onPressed: () => onRemovePart(part),
              ),
            ],
          ),
        ),

      const SizedBox(height: 16),

      TextField(
        controller: partController,
        decoration: InputDecoration(
          labelText: "Parça Adı",
          labelStyle: TextStyle(color: Colors.grey.shade600),
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
          ),
          prefixIcon: Icon(
            Icons.add_circle_outline,
            color: Colors.blue.shade600,
          ),
        ),
      ),

      const SizedBox(height: 12),

      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: request.status.canEditParts ? onAddPart : null,
          icon: const Icon(Icons.add),
          label: const Text(
            "Parça Ekle",
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: Colors.blue.shade700,
            elevation: 0,
            side: BorderSide(color: Colors.blue.shade300, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    ];
  }
}

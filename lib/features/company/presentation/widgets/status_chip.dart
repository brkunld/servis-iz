import 'package:flutter/material.dart';

/// Şirket panelindeki durum etiketlerinin renkleri. Talep durumlarının yanında
/// teknisyen için "Boşta" etiketi de vardır.
abstract final class StatusColors {
  static Color background(String status) => switch (status) {
    "Bekliyor" => Colors.orange.shade100,
    "Devam Ediyor" => Colors.purple.shade100,
    "Tamamlandı" => Colors.green.shade100,
    "Boşta" => Colors.grey.shade200,
    _ => Colors.grey.shade100,
  };

  static Color text(String status) => switch (status) {
    "Bekliyor" => Colors.orange.shade700,
    "Devam Ediyor" => Colors.purple.shade700,
    "Tamamlandı" => Colors.green.shade700,
    _ => Colors.grey.shade700,
  };
}

/// Durum etiketi (ör. "Bekliyor").
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: StatusColors.background(status),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: StatusColors.text(status),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Müşteri kartındaki küçük sayaç (ör. "3 Bekliyor").
class StatCountChip extends StatelessWidget {
  const StatCountChip({
    super.key,
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 0),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Column(
        children: [
          Text(
            "$count",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Alt sayfaların (bottom sheet) üstündeki tutamaç çizgisi.
class SheetHandle extends StatelessWidget {
  const SheetHandle({
    super.key,
    this.margin = const EdgeInsets.only(top: 12),
    this.color,
  });

  final EdgeInsets margin;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: color ?? Colors.grey.shade400,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

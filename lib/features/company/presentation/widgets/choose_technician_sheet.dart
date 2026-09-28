import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobil_proje/features/requests/data/request_repository.dart';
import 'package:mobil_proje/features/technicians/data/technician_providers.dart';

/// Şirketin bekleyen talebe boştaki bir teknisyeni atadığı alt sayfa.
/// Atama, teknisyenin kendisinin görev almasıyla aynı transaction'ı kullanır
/// (`RequestRepository.assign`).
Future<void> showChooseTechnicianSheet(
  BuildContext context, {
  required String requestId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _ChooseTechnicianSheet(requestId: requestId),
  );
}

class _ChooseTechnicianSheet extends ConsumerWidget {
  const _ChooseTechnicianSheet({required this.requestId});

  final String requestId;

  Future<void> _assign(
    BuildContext context,
    WidgetRef ref,
    String technicianId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref
          .read(requestRepositoryProvider)
          .assign(requestId: requestId, technicianId: technicianId);
      navigator.pop();
    } catch (e) {
      navigator.pop();
      messenger.showSnackBar(SnackBar(content: Text("Atama yapılamadı: $e")));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final techs = ref.watch(availableTechniciansProvider).valueOrNull;

    if (techs == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (techs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.engineering_outlined, size: 64, color: Colors.grey),
              SizedBox(height: 16),
              Text(
                "Boşta teknisyen yok",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: const Row(
            children: [
              Icon(Icons.engineering, color: Colors.blue),
              SizedBox(width: 12),
              Text(
                "Teknisyen Seç",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(8),
            children: [
              for (final tech in techs)
                Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      child: const Icon(Icons.person, color: Colors.blue),
                    ),
                    title: Text(
                      tech.name ?? "Teknisyen",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(tech.email ?? ""),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => _assign(context, ref, tech.id),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

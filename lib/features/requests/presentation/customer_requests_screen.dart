import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:mobil_proje/core/router/app_routes.dart';
import 'package:mobil_proje/core/widgets/app_background.dart';
import 'package:mobil_proje/features/auth/data/auth_repository.dart';
import 'package:mobil_proje/features/auth/data/session_providers.dart';
import 'package:mobil_proje/features/requests/data/request_providers.dart';
import 'package:mobil_proje/features/requests/data/request_repository.dart';
import 'package:mobil_proje/features/requests/domain/service_request.dart';
import 'package:mobil_proje/features/requests/presentation/widgets/customer_request_card.dart';

/// Müşterinin ana ekranı: kendi talepleri, yeni talep, puanlama.
class CustomerRequestsScreen extends ConsumerStatefulWidget {
  const CustomerRequestsScreen({super.key});

  @override
  ConsumerState<CustomerRequestsScreen> createState() =>
      _CustomerRequestsScreenState();
}

class _CustomerRequestsScreenState
    extends ConsumerState<CustomerRequestsScreen> {
  /// Aynı anda yalnız bir kart açık olur.
  String? expandedCardId;

  /// Kart kapanıp açılınca seçilen yıldız ve yazılan yorum kaybolmasın diye
  /// ekranda tutulur (talep id'sine göre).
  final Map<String, int> selectedStars = {};
  final Map<String, TextEditingController> commentControllers = {};

  @override
  void dispose() {
    for (final controller in commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _logout() async {
    try {
      // Giriş ekranına geçişi router yapar.
      await ref.read(authRepositoryProvider).signOut();
    } catch (e) {
      if (!mounted) return;
      _showSnack("Çıkış yapılamadı: $e");
    }
  }

  void _openMap(ServiceRequest request) {
    final location = request.location;
    if (location == null) {
      _showSnack("Konum bilgisi eksik.");
      return;
    }

    final technicianId = request.technicianId ?? '';
    if (technicianId.isEmpty) {
      _showSnack("Teknisyen atanmamış.");
      return;
    }

    context.push(
      AppRoutes.map(
        viewer: MapViewer.customer,
        technicianId: technicianId,
        customerLat: location.lat,
        customerLng: location.lng,
      ),
    );
  }

  void _openChat(ServiceRequest request) {
    final technicianId = request.technicianId;
    if (technicianId == null) return;
    context.push(
      AppRoutes.chat(
        requestId: request.id,
        customerId: request.customerId,
        technicianId: technicianId,
      ),
    );
  }

  Future<void> _deleteRequest(ServiceRequest request) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Talep Silinsin mi?"),
        content: const Text("Bu işlem geri alınamaz."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("İptal"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Sil"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await ref.read(requestRepositoryProvider).deleteByCustomer(request);
      if (!mounted) return;
      _showSnack("Talep silindi.");
    } catch (e) {
      if (!mounted) return;
      _showSnack("Silme hatası: $e");
    }
  }

  Future<void> _rate(ServiceRequest request) async {
    final messenger = ScaffoldMessenger.of(context);
    final stars = selectedStars[request.id] ?? 0;
    final technicianId = request.technicianId;
    if (stars == 0 || technicianId == null) return;

    try {
      await ref
          .read(requestRepositoryProvider)
          .rate(
            requestId: request.id,
            technicianId: technicianId,
            stars: stars,
            comment: commentControllers[request.id]?.text ?? '',
          );

      messenger.showSnackBar(
        const SnackBar(
          content: Text("Değerlendirmeniz kaydedildi!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text("Hata: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserIdProvider);

    if (uid == null) {
      // Oturum kapanıyor; router giriş ekranına götürecek.
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final requests = ref.watch(customerRequestsProvider(uid));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Taleplerim",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
            tooltip: "Çıkış Yap",
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.green,
        icon: const Icon(Icons.add_circle_outline, size: 28),
        label: const Text(
          "Yeni Talep",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () => context.push(AppRoutes.newRequest),
      ),
      body: Stack(
        children: [
          const AppBackground(),
          requests.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            error: (e, _) => _EmptyRequests(error: e),
            data: (list) {
              if (list.isEmpty) return const _EmptyRequests();

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final request = list[index];
                  final isExpanded = expandedCardId == request.id;
                  final commentController = commentControllers.putIfAbsent(
                    request.id,
                    TextEditingController.new,
                  );

                  return CustomerRequestCard(
                    request: request,
                    isExpanded: isExpanded,
                    selectedStars: selectedStars[request.id] ?? 0,
                    commentController: commentController,
                    onToggle: () => setState(() {
                      expandedCardId = isExpanded ? null : request.id;
                    }),
                    onStarSelected: (stars) =>
                        setState(() => selectedStars[request.id] = stars),
                    onChat: () => _openChat(request),
                    onOpenMap: () => _openMap(request),
                    onDelete: () => _deleteRequest(request),
                    onRate: () => _rate(request),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyRequests extends StatelessWidget {
  const _EmptyRequests({this.error});

  final Object? error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 120,
            color: Colors.white.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 20),
          Text(
            error == null ? "Henüz talebiniz yok" : "Talepler yüklenemedi",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            error == null
                ? "Yeni talep oluşturmak için\naşağıdaki butona tıklayın"
                : "$error",
            style: const TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

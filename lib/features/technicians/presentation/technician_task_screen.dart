import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import 'package:mobil_proje/core/router/app_routes.dart';
import 'package:mobil_proje/core/widgets/app_background.dart';
import 'package:mobil_proje/features/auth/data/auth_repository.dart';
import 'package:mobil_proje/features/auth/data/session_providers.dart';
import 'package:mobil_proje/features/requests/data/request_providers.dart';
import 'package:mobil_proje/features/requests/data/request_repository.dart';
import 'package:mobil_proje/features/requests/domain/service_request.dart';
import 'package:mobil_proje/features/requests/domain/task_exception.dart';
import 'package:mobil_proje/features/technicians/data/technician_repository.dart';
import 'package:mobil_proje/features/technicians/presentation/widgets/active_task_card.dart';
import 'package:mobil_proje/features/technicians/presentation/widgets/available_task_card.dart';
import 'package:mobil_proje/features/technicians/presentation/widgets/completed_task_card.dart';

/// Teknisyenin ana ekranı.
///
/// Devam eden bir görevi varsa yalnız o görev (ve tamamlananlar) görünür;
/// yoksa boştaki görevler listelenir. Hangisinin gösterileceğine
/// `activeTaskProvider` karar verir.
class TechnicianTaskScreen extends ConsumerStatefulWidget {
  const TechnicianTaskScreen({super.key});

  @override
  ConsumerState<TechnicianTaskScreen> createState() =>
      _TechnicianTaskScreenState();
}

class _TechnicianTaskScreenState extends ConsumerState<TechnicianTaskScreen> {
  final TextEditingController partController = TextEditingController();
  StreamSubscription<Position>? locationStream;

  bool loading = false;
  String? expandedAvailableId;

  @override
  void initState() {
    super.initState();
    startLocationUpdates();
  }

  @override
  void dispose() {
    partController.dispose();
    locationStream?.cancel();
    super.dispose();
  }

  /// Teknisyen uygulamayı açık tuttuğu sürece konumu Firestore'a yazılır;
  /// müşteri ve şirket haritada bunu izler.
  Future<void> startLocationUpdates() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;
    final technicians = ref.read(technicianRepositoryProvider);

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint("Kalıcı izin reddedildi");
      return;
    }
    await Geolocator.requestPermission();
    await Geolocator.isLocationServiceEnabled();

    await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
    if (!mounted) return;

    locationStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 20,
            timeLimit: Duration(hours: 12),
          ),
        ).listen((Position pos) async {
          try {
            await technicians.updateLocation(uid, pos.latitude, pos.longitude);
            debugPrint("Konum güncellendi: ${pos.latitude}, ${pos.longitude}");
          } catch (e) {
            debugPrint("Firebase yazılamadı: $e");
          }
        });
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> takeTask(String uid, ServiceRequest request) async {
    String message = "Görev sana atandı!";
    try {
      await ref
          .read(requestRepositoryProvider)
          .assign(requestId: request.id, technicianId: uid);
    } on TaskException catch (e) {
      message = e.message;
    } catch (e) {
      message = "Görev alınamadı: $e";
    }
    _showSnack(message);
  }

  Future<void> addPart(ServiceRequest request) async {
    final part = partController.text.trim();
    if (part.isEmpty) return;

    await ref.read(requestRepositoryProvider).addPart(request, part);
    partController.clear();
  }

  Future<void> removePart(ServiceRequest request, String part) =>
      ref.read(requestRepositoryProvider).removePart(request, part);

  Future<void> completeTask(ServiceRequest request) async {
    setState(() => loading = true);

    try {
      await ref.read(requestRepositoryProvider).complete(request);
    } catch (e) {
      _showSnack("Görev tamamlanamadı: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void openMap(String uid, ServiceRequest request) {
    final location = request.location;
    if (location == null) {
      _showSnack("Bu talebin konumu bulunamadı.");
      return;
    }

    context.push(
      AppRoutes.map(
        viewer: MapViewer.technician,
        technicianId: uid,
        customerId: request.customerId,
        customerLat: location.lat,
        customerLng: location.lng,
      ),
    );
  }

  void openChat(String uid, ServiceRequest request) {
    context.push(
      AppRoutes.chat(
        requestId: request.id,
        customerId: request.customerId,
        technicianId: uid,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Görevlerim"),
        backgroundColor: Colors.blue,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            icon: const Icon(Icons.logout, color: Colors.black),
          ),
        ],
      ),
      body: Stack(
        children: [
          const AppBackground(),
          if (uid == null)
            const Center(child: CircularProgressIndicator())
          else
            _body(uid),
        ],
      ),
    );
  }

  Widget _body(String uid) {
    final activeTask = ref.watch(activeTaskProvider(uid));
    final completed =
        ref.watch(completedTasksProvider(uid)).valueOrNull ?? const [];

    return activeTask.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: Colors.blue.shade600)),
      error: (e, _) => Center(
        child: Text("Hata: $e", style: TextStyle(color: Colors.red.shade700)),
      ),
      data: (active) {
        if (active != null) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ActiveTaskCard(
                request: active,
                partController: partController,
                loading: loading,
                onOpenMap: () => openMap(uid, active),
                onChat: () => openChat(uid, active),
                onAddPart: () => addPart(active),
                onRemovePart: (part) => removePart(active, part),
                onComplete: () => completeTask(active),
              ),
              ..._completedSection(uid, completed),
            ],
          );
        }
        return _availableTasks(uid, completed);
      },
    );
  }

  Widget _availableTasks(String uid, List<ServiceRequest> completed) {
    final pending = ref.watch(pendingRequestsProvider);

    if (pending.isLoading && !pending.hasValue) {
      return Center(
        child: CircularProgressIndicator(color: Colors.blue.shade600),
      );
    }
    final available = pending.valueOrNull ?? const [];

    if (available.isEmpty && completed.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 80, color: Colors.blue.shade200),
            const SizedBox(height: 16),
            Text(
              "Şu anda görünür görev yok.",
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (available.isNotEmpty) ...[
          _sectionTitle("Boştaki Görevler"),
          const SizedBox(height: 12),
          for (final request in available)
            AvailableTaskCard(
              request: request,
              isExpanded: expandedAvailableId == request.id,
              onToggle: () => setState(() {
                expandedAvailableId = expandedAvailableId == request.id
                    ? null
                    : request.id;
              }),
              onTake: () => takeTask(uid, request),
              onOpenMap: () => openMap(uid, request),
              onChat: () => openChat(uid, request),
            ),
        ],
        ..._completedSection(uid, completed),
      ],
    );
  }

  List<Widget> _completedSection(String uid, List<ServiceRequest> completed) {
    if (completed.isEmpty) return const [];
    return [
      const SizedBox(height: 24),
      _sectionTitle("Tamamlanan Görevlerim"),
      const SizedBox(height: 12),
      for (final request in completed)
        CompletedTaskCard(
          request: request,
          onChat: () => openChat(uid, request),
        ),
    ];
  }

  Widget _sectionTitle(String text) => Text(
    text,
    style: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: Colors.blue.shade800,
    ),
  );
}

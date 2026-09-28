import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mobil_proje/screens/chat_screen.dart';
import 'package:mobil_proje/utils/background.dart';
import 'package:mobil_proje/utils/task_service.dart' as task_service;
import 'map_screen.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';

class TechnicianTaskScreen extends StatefulWidget {
  const TechnicianTaskScreen({super.key});

  @override
  State<TechnicianTaskScreen> createState() => _TechnicianTaskScreenState();
}

class _TechnicianTaskScreenState extends State<TechnicianTaskScreen> {
  final TextEditingController partController = TextEditingController();
  StreamSubscription<Position>? locationStream;

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

  String? selectedRequestId;
  bool loading = false;

  String? expandedAvailableId;

  void startLocationUpdates() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      print("Kalıcı izin reddedildi");
      return;
    }
    await Geolocator.requestPermission();
    await Geolocator.isLocationServiceEnabled();

    await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

    locationStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 20, 
            timeLimit: Duration(hours: 12),
          ),
        ).listen((Position pos) async {
          try {
            await FirebaseFirestore.instance
                .collection("technicians")
                .doc(uid)
                .update({
                  "location": {
                    "lat": pos.latitude,
                    "lng": pos.longitude,
                    "updatedAt": FieldValue.serverTimestamp(),
                  },
                });

            print(
              "📍 [BACKGROUND] Konum güncellendi: ${pos.latitude}, ${pos.longitude}",
            );
          } catch (e) {
            print("Firebase yazılamadı: $e");
          }
        });
  }

  Future<void> removePart(String part) async {
    if (selectedRequestId == null) return;

    await FirebaseFirestore.instance
        .collection("requests")
        .doc(selectedRequestId)
        .update({
          "usedParts": FieldValue.arrayRemove([part]),
        });
  }

  Stream<DocumentSnapshot?> getActiveTaskStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    final uid = user.uid;

    return FirebaseFirestore.instance
        .collection("requests")
        .where("technicianId", isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;

          for (var doc in snapshot.docs) {
            if (doc["status"] != "Tamamlandı") {
              selectedRequestId = doc.id;
              return doc;
            }
          }
          return null;
        });
  }

  Stream<QuerySnapshot> getAvailableTasks() {
    return FirebaseFirestore.instance
        .collection("requests")
        .where("status", isEqualTo: "Bekliyor")
        .snapshots();
  }

  Stream<QuerySnapshot> getCompletedTasksForTechnician() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Stream.empty();

    return FirebaseFirestore.instance
        .collection("requests")
        .where("technicianId", isEqualTo: user.uid)
        .where("status", isEqualTo: "Tamamlandı")
        .snapshots();
  }

  Future<void> takeTask(String id) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    String message = "Görev sana atandı!";
    try {
      await task_service.assignTask(requestId: id, technicianId: uid);
    } on task_service.TaskException catch (e) {
      message = e.message;
    } catch (e) {
      message = "Görev alınamadı: $e";
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> addPart() async {
    if (selectedRequestId == null || partController.text.trim().isEmpty) return;

    await FirebaseFirestore.instance
        .collection("requests")
        .doc(selectedRequestId)
        .update({
          "usedParts": FieldValue.arrayUnion([partController.text.trim()]),
        });

    partController.clear();
  }

  Future<void> completeTask() async {
    if (selectedRequestId == null) return;

    setState(() => loading = true);

    try {
      await task_service.completeTask(
        requestId: selectedRequestId!,
        technicianId: FirebaseAuth.instance.currentUser!.uid,
      );

      if (mounted) setState(() => selectedRequestId = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Görev tamamlanamadı: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void openMap(BuildContext context, Map<String, dynamic> data) {
    final technicianUser = FirebaseAuth.instance.currentUser;

    if (technicianUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Oturum bulunamadı.")));
      return;
    }

    if (data["location"] == null ||
        data["location"]["lat"] == null ||
        data["location"]["lng"] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Bu talebin konumu bulunamadı.")),
      );
      return;
    }

    final customerLat = data["location"]["lat"];
    final customerLng = data["location"]["lng"];

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UniversalMapScreen(
          userType: 'technician',
          technicianId: technicianUser.uid,
          customerLat: customerLat,
          customerLng: customerLng,
          customerId: data["customerId"],
        ),
      ),
    );
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, "/login", (route) => false);
  }
  Color statusColor(String s) {
    switch (s) {
      case "Bekliyor":
        return Colors.blue.shade100;
      case "Atandı":
        return Colors.blue.shade200;
      case "Devam Ediyor":
        return Colors.blue.shade300;
      case "Tamamlandı":
        return Colors.blue.shade400;
      default:
        return Colors.grey.shade200;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Görevlerim"),
        backgroundColor: Colors.blue,
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: logout,
            icon: Icon(Icons.logout, color: Colors.black),
          ),
        ],
      ),
      body: Stack(
        children: [
          const AppBackground(),
          StreamBuilder<DocumentSnapshot?>(
            stream: getActiveTaskStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: Colors.blue.shade600),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    "Hata: ${snapshot.error}",
                    style: TextStyle(color: Colors.red.shade700),
                  ),
                );
              }

              final activeDoc = snapshot.data;

              if (activeDoc != null) {
                return buildActiveTaskWithCompleted(activeDoc);
              }

              return StreamBuilder<QuerySnapshot>(
                stream: getAvailableTasks(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: Colors.blue.shade600,
                      ),
                    );
                  }

                  final docs = snap.data?.docs ?? [];

                  return StreamBuilder<QuerySnapshot>(
                    stream: getCompletedTasksForTechnician(),
                    builder: (context, completedSnap) {
                      final completedDocs = completedSnap.data?.docs ?? [];

                      if (docs.isEmpty && completedDocs.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 80,
                                color: Colors.blue.shade200,
                              ),
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
                          if (docs.isNotEmpty) ...[
                            Text(
                              "Boştaki Görevler",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...docs.map((d) {
                              final data = d.data() as Map<String, dynamic>;
                              final bool isExpanded =
                                  expandedAvailableId == d.id;

                              final String issue =
                                  data["issue"]?.toString() ?? "Arıza belirsiz";
                              final String city =
                                  data["city"]?.toString() ?? "-";
                              final String district =
                                  data["district"]?.toString() ?? "-";
                              final String address =
                                  data["address"]?.toString() ??
                                  "Adres belirtilmemiş";
                              final String customerName =
                                  data["name"]?.toString() ?? "İsimsiz";
                              final String phone =
                                  data["phone"]?.toString() ?? "Telefon yok";

                              return Card(
                                elevation: isExpanded ? 4 : 2,
                                margin: const EdgeInsets.only(bottom: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    setState(() {
                                      if (expandedAvailableId == d.id) {
                                        expandedAvailableId = null;
                                      } else {
                                        expandedAvailableId = d.id;
                                      }
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Colors.blue.shade400,
                                                    Colors.blue.shade600,
                                                  ],
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(12),
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
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    issue,
                                                    maxLines: isExpanded
                                                        ? null
                                                        : 2,
                                                    overflow: isExpanded
                                                        ? TextOverflow.visible
                                                        : TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          Colors.grey.shade800,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.location_on,
                                                        size: 16,
                                                        color: Colors
                                                            .blue
                                                            .shade600,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Flexible(
                                                        child: Text(
                                                          "$city / $district",
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            color: Colors
                                                                .grey
                                                                .shade600,
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
                                              Divider(
                                                color: Colors.grey.shade300,
                                              ),
                                              const SizedBox(height: 16),

                                              _buildInfoRow(
                                                Icons.person_outline,
                                                "Müşteri",
                                                customerName,
                                              ),
                                              const SizedBox(height: 12),
                                              _buildInfoRow(
                                                Icons.phone_outlined,
                                                "Telefon",
                                                phone,
                                              ),
                                              const SizedBox(height: 12),
                                              _buildInfoRow(
                                                Icons.home_outlined,
                                                "Adres",
                                                address,
                                              ),

                                              const SizedBox(height: 16),

                                              SizedBox(
                                                width: double.infinity,
                                                child: OutlinedButton.icon(
                                                  onPressed: () =>
                                                      openMap(context, data),
                                                  icon: Icon(
                                                    Icons.map_outlined,
                                                    color: Colors.blue.shade700,
                                                  ),
                                                  label: Text(
                                                    "Haritada Göster",
                                                    style: TextStyle(
                                                      color:
                                                          Colors.blue.shade700,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          crossFadeState: isExpanded
                                              ? CrossFadeState.showSecond
                                              : CrossFadeState.showFirst,
                                          duration: const Duration(
                                            milliseconds: 300,
                                          ),
                                        ),

                                        const SizedBox(height: 16),

                                        Row(
                                          children: [
                                            Expanded(
                                              flex: 2,
                                              child: ElevatedButton.icon(
                                                onPressed: () => takeTask(d.id),
                                                icon: const Icon(
                                                  Icons.check_circle_outline,
                                                  size: 20,
                                                ),
                                                label: const Text("Görevi Al"),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      Colors.blue.shade600,
                                                  foregroundColor: Colors.white,
                                                  elevation: 0,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 14,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: ElevatedButton(
                                                onPressed: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => ChatScreen(
                                                        requestId: d.id,
                                                        customerId:
                                                            data["customerId"],
                                                        technicianId:
                                                            FirebaseAuth
                                                                .instance
                                                                .currentUser!
                                                                .uid,
                                                        companyId: "none",
                                                      ),
                                                    ),
                                                  );
                                                },
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.white,
                                                  foregroundColor:
                                                      Colors.blue.shade700,
                                                  elevation: 0,
                                                  side: BorderSide(
                                                    color: Colors.blue.shade300,
                                                    width: 1.5,
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 14,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.chat_bubble_outline,
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
                            }).toList(),
                          ],

                          if (completedDocs.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Text(
                              "Tamamlanan Görevlerim",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ...completedDocs.map(
                              (c) => _buildCompletedTaskCard(c),
                            ),
                          ],
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue.shade700, size: 20),
          const SizedBox(width: 12),
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
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedTaskCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final String issue = data["issue"]?.toString() ?? "Arıza belirsiz";
    final String city = data["city"]?.toString() ?? "-";
    final String district = data["district"]?.toString() ?? "-";

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.check_circle,
                    color: Colors.blue.shade700,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        issue,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: Colors.blue.shade600,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              "$city / $district",
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "Tamamlandı",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        requestId: doc.id,
                        customerId: data["customerId"],
                        technicianId: FirebaseAuth.instance.currentUser!.uid,
                        companyId: "none",
                      ),
                    ),
                  );
                },
                icon: Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.blue.shade700,
                  size: 18,
                ),
                label: Text(
                  "Sohbeti Aç",
                  style: TextStyle(
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  side: BorderSide(color: Colors.blue.shade300, width: 1.4),
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

  Widget buildActiveTaskWithCompleted(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final List<dynamic> usedParts = data["usedParts"] ?? [];

    return StreamBuilder<QuerySnapshot>(
      stream: getCompletedTasksForTechnician(),
      builder: (context, completedSnap) {
        final completedDocs = completedSnap.data?.docs ?? [];

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.blue.shade400,
                                    Colors.blue.shade600,
                                  ],
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
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor(data["status"]),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            data["status"],
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: Colors.blue.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Arıza:",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          Padding(
                            padding: const EdgeInsets.only(left: 28),
                            child: Text(
                              data["issue"] ?? "",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on_outlined,
                                color: Colors.blue.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "Adres:",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Padding(
                            padding: const EdgeInsets.only(left: 28),
                            child: Text(
                              data["address"] ?? "",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => openMap(
                          context,
                          data,
                        ),
                        icon: Icon(
                          Icons.map_outlined,
                          color: Colors.blueAccent,
                        ),
                        label: Text(
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
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                requestId: doc.id,
                                customerId: data["customerId"],
                                technicianId:
                                    FirebaseAuth.instance.currentUser!.uid,
                                companyId: "none",
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.chat_bubble_outline),
                        label: const Text(
                          "Müşteri ile Mesajlaş",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
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
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    if (usedParts.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          "Henüz parça eklenmedi.",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    if (usedParts.isNotEmpty)
                      ...usedParts.map(
                        (p) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
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

                              Expanded(
                                child: Text(
                                  p.toString(),
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),

                              IconButton(
                                icon: const Icon(
                                  Icons.clear,
                                  color: Colors.red,
                                ),
                                onPressed: () async {
                                  await removePart(p);
                                },
                              ),
                            ],
                          ),
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
                          borderSide: BorderSide(
                            color: Colors.blue.shade600,
                            width: 2,
                          ),
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
                        onPressed: addPart,
                        icon: const Icon(Icons.add),
                        label: const Text(
                          "Parça Ekle",
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: loading ? null : completeTask,
                        icon: loading
                            ? const SizedBox.shrink()
                            : const Icon(Icons.check_circle, size: 22),
                        label: loading
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
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
            ),

            if (completedDocs.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                "Tamamlanan Görevlerim",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
              const SizedBox(height: 12),
              ...completedDocs.map((c) => _buildCompletedTaskCard(c)),
            ],
          ],
        );
      },
    );
  }
}

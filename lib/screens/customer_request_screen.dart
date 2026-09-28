import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobil_proje/screens/chat_screen.dart';
import 'package:mobil_proje/utils/background.dart';
import 'package:mobil_proje/utils/task_service.dart';
import 'new_request_screen.dart';
import 'map_screen.dart';

class CustomerRequestMenu extends StatefulWidget {
  const CustomerRequestMenu({super.key});

  @override
  State<CustomerRequestMenu> createState() => _CustomerRequestMenuState();
}

class _CustomerRequestMenuState extends State<CustomerRequestMenu> {
  String? expandedCardId;
  Map<String, int> selectedStars = {};
  Map<String, TextEditingController> commentControllers = {};

  @override
  void dispose() {
    for (var controller in commentControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _logout(BuildContext context) async {
    try {
      await FirebaseAuth.instance.signOut();
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, "/login", (route) => false);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Çıkış yapılamadı: $e")));
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case "Bekliyor":
        return Colors.green.shade300;
      case "Atandı":
        return Colors.blue.shade200;
      case "Devam Ediyor":
        return Colors.orange.shade200;
      case "Tamamlandı":
        return Colors.green;
      default:
        return Colors.grey.shade300;
    }
  }


  void _openMap(
    BuildContext context,
    String technicianId,
    Map<String, dynamic> requestData,
  ) {
    final location = requestData["location"];
    if (location == null ||
        location["lat"] == null ||
        location["lng"] == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Konum bilgisi eksik.")));
      return;
    }

    if (technicianId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Teknisyen atanmamış.")));
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UniversalMapScreen(
          userType: 'customer',
          technicianId: technicianId,
          customerLat: location["lat"],
          customerLng: location["lng"],
        ),
      ),
    );
  }

  Future<void> _deleteRequest(String id, BuildContext context) async {
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
      await FirebaseFirestore.instance.collection("requests").doc(id).delete();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Talep silindi.")));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Silme hatası: $e")));
    }
  }

  Future<void> _rateTask(
    String requestId,
    String techId,
    int stars,
    String comment,
    BuildContext context,
  ) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      await rateTask(
        requestId: requestId,
        technicianId: techId,
        stars: stars,
        comment: comment,
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
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      Future.delayed(Duration.zero, () {
        Navigator.pushNamedAndRemoveUntil(context, "/login", (_) => false);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
            onPressed: () => _logout(context),
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
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NewRequestScreen()),
          );
        },
      ),
      body: Stack(
        children: [
          const AppBackground(),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection("requests")
                .where("customerId", isEqualTo: user.uid)
                .orderBy("createdAt", descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 120,
                        color: Colors.white.withOpacity(0.7),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "Henüz talebiniz yok",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Yeni talep oluşturmak için\naşağıdaki butona tıklayın",
                        style: TextStyle(color: Colors.white70, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              final docs = snapshot.data!.docs;

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map<String, dynamic>;

                  final status = data["status"] ?? "Bekliyor";
                  final issue = data["issue"] ?? "Bildirilmedi";
                  final address = data["address"] ?? "Adres belirtilmemiş";
                  final kat = data["kat"] ?? "-";
                  final daire = data["daire"] ?? "-";

                  final createdAt = data["createdAt"] is Timestamp
                      ? (data["createdAt"] as Timestamp).toDate()
                      : null;

                  final bool canOpenMap =
                      status == "Atandı" || status == "Devam Ediyor";
                  final bool canDelete = status == "Bekliyor";
                  final bool isExpanded = expandedCardId == doc.id;

                  if (!commentControllers.containsKey(doc.id)) {
                    commentControllers[doc.id] = TextEditingController();
                  }

                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => setState(() {
                          expandedCardId = isExpanded ? null : doc.id;
                        }),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: _statusColor(status).withOpacity(0.2),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(20),
                                    topRight: Radius.circular(20),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            issue,
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
                                            createdAt != null
                                                ? "${createdAt.day}/${createdAt.month}/${createdAt.year} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}"
                                                : "Tarih yok",
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _statusColor(status),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        status,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isExpanded) ...[
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.location_on_outlined,
                                            size: 18,
                                            color: Colors.grey.shade600,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              address,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade700,
                                              ),
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
                                    ] else ...[
                                      _buildInfoRow(
                                        Icons.location_on,
                                        "Adres",
                                        address,
                                      ),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _buildInfoRow(
                                              Icons.stairs,
                                              "Kat",
                                              kat,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: _buildInfoRow(
                                              Icons.door_front_door,
                                              "Daire",
                                              daire,
                                            ),
                                          ),
                                        ],
                                      ),

                                      if (data["technicianId"] != null) ...[
                                        const SizedBox(height: 20),
                                        const Divider(),
                                        const SizedBox(height: 16),
                                        FutureBuilder<DocumentSnapshot>(
                                          future: FirebaseFirestore.instance
                                              .collection("technicians")
                                              .doc(data["technicianId"])
                                              .get(),
                                          builder: (context, techSnap) {
                                            if (!techSnap.hasData) {
                                              return const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              );
                                            }

                                            final tech =
                                                techSnap.data!.data()
                                                    as Map<String, dynamic>;

                                            return Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                border: Border.all(
                                                  color: Colors.blue.shade200,
                                                ),
                                              ),
                                              child: Column(
                                                children: [
                                                  Row(
                                                    children: [
                                                      Container(
                                                        decoration:
                                                            BoxDecoration(
                                                              shape: BoxShape
                                                                  .circle,
                                                              border: Border.all(
                                                                color:
                                                                    Colors.blue,
                                                                width: 3,
                                                              ),
                                                            ),
                                                        child: CircleAvatar(
                                                          radius: 30,
                                                          backgroundColor:
                                                              Colors
                                                                  .grey
                                                                  .shade200,
                                                          backgroundImage:
                                                              (tech["photoUrl"] !=
                                                                      null &&
                                                                  tech["photoUrl"]
                                                                      .toString()
                                                                      .isNotEmpty)
                                                              ? NetworkImage(
                                                                  tech["photoUrl"],
                                                                )
                                                              : const AssetImage(
                                                                  "assets/default_technician.jpg",
                                                                ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 16),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            const Text(
                                                              "Atanan Teknisyen",
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color:
                                                                    Colors.grey,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 4,
                                                            ),
                                                            Text(
                                                              tech["name"] ??
                                                                  "Teknisyen",
                                                              style: const TextStyle(
                                                                fontSize: 18,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .black87,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              height: 4,
                                                            ),
                                                            Row(
                                                              children: [
                                                                Icon(
                                                                  Icons.phone,
                                                                  size: 14,
                                                                  color: Colors
                                                                      .grey
                                                                      .shade600,
                                                                ),
                                                                const SizedBox(
                                                                  width: 4,
                                                                ),
                                                                Text(
                                                                  tech["phone"] ??
                                                                      "",
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        14,
                                                                    color: Colors
                                                                        .grey
                                                                        .shade700,
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
                                                    onPressed: () {
                                                      Navigator.push(
                                                        context,
                                                        MaterialPageRoute(
                                                          builder: (_) =>
                                                              ChatScreen(
                                                                requestId:
                                                                    doc.id,
                                                                customerId:
                                                                    user.uid,
                                                                technicianId:
                                                                    data["technicianId"],
                                                                companyId:
                                                                    "none",
                                                              ),
                                                        ),
                                                      );
                                                    },
                                                    icon: const Icon(
                                                      Icons.chat_bubble_outline,
                                                    ),
                                                    label: const Text(
                                                      "Mesajlaş",
                                                    ),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor:
                                                          Colors.deepPurple,
                                                      foregroundColor:
                                                          Colors.white,
                                                      minimumSize: const Size(
                                                        double.infinity,
                                                        50,
                                                      ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                  if (canOpenMap &&
                                                      data["location"] !=
                                                          null) ...[
                                                    const SizedBox(height: 12),
                                                    ElevatedButton.icon(
                                                      onPressed: () => _openMap(
                                                        context,
                                                        data["technicianId"]
                                                            as String,
                                                        data,
                                                      ),
                                                      icon: const Icon(
                                                        Icons.map_outlined,
                                                      ),
                                                      label: const Text(
                                                        "Haritada Gör",
                                                      ),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.blue,
                                                        foregroundColor:
                                                            Colors.white,
                                                        minimumSize: const Size(
                                                          double.infinity,
                                                          50,
                                                        ),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ],

                                      const SizedBox(height: 16),

                                      if (canDelete)
                                        ElevatedButton.icon(
                                          onPressed: () =>
                                              _deleteRequest(doc.id, context),
                                          icon: const Icon(
                                            Icons.delete_outline,
                                          ),
                                          label: const Text("Talebi Sil"),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                            minimumSize: const Size(
                                              double.infinity,
                                              50,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        ),

                                      if (status == "Tamamlandı" &&
                                          data["rated"] != true) ...[
                                        const SizedBox(height: 20),
                                        Container(
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: [
                                                Colors.amber.shade50,
                                                Colors.amber.shade100,
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: Colors.amber.shade300,
                                              width: 2,
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          10,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.amber,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                    ),
                                                    child: const Icon(
                                                      Icons.star,
                                                      color: Colors.white,
                                                      size: 24,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  const Text(
                                                    "Hizmeti Değerlendir",
                                                    style: TextStyle(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: Colors.black87,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 20),
                                              Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: List.generate(5, (i) {
                                                  int starIndex = i + 1;
                                                  int currentStars =
                                                      selectedStars[doc.id] ??
                                                      0;
                                                  bool filled =
                                                      starIndex <= currentStars;

                                                  return IconButton(
                                                    onPressed: () {
                                                      setState(() {
                                                        selectedStars[doc.id] =
                                                            starIndex;
                                                      });
                                                    },
                                                    icon: Icon(
                                                      filled
                                                          ? Icons.star_rounded
                                                          : Icons
                                                                .star_outline_rounded,
                                                      color: filled
                                                          ? Colors.amber
                                                          : Colors
                                                                .grey
                                                                .shade400,
                                                      size: 40,
                                                    ),
                                                  );
                                                }),
                                              ),

                                              const SizedBox(height: 16),

                                              TextField(
                                                controller:
                                                    commentControllers[doc.id],
                                                maxLines: 3,
                                                decoration: InputDecoration(
                                                  hintText:
                                                      "Yorumunuzu yazın (isteğe bağlı)",
                                                  filled: true,
                                                  fillColor: Colors.white,
                                                  border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                    borderSide: BorderSide(
                                                      color:
                                                          Colors.amber.shade300,
                                                    ),
                                                  ),
                                                  focusedBorder:
                                                      OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        borderSide: BorderSide(
                                                          color: Colors
                                                              .amber
                                                              .shade600,
                                                          width: 2,
                                                        ),
                                                      ),
                                                ),
                                              ),

                                              const SizedBox(height: 16),

                                              ElevatedButton.icon(
                                                onPressed:
                                                    (selectedStars[doc.id] ??
                                                            0) ==
                                                        0
                                                    ? null
                                                    : () {
                                                        _rateTask(
                                                          doc.id,
                                                          data["technicianId"],
                                                          selectedStars[doc
                                                              .id]!,
                                                          commentControllers[doc
                                                                  .id]!
                                                              .text,
                                                          context,
                                                        );
                                                      },
                                                icon: const Icon(
                                                  Icons.send_rounded,
                                                ),
                                                label: const Text("Gönder"),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor:
                                                      (selectedStars[doc.id] ??
                                                              0) ==
                                                          0
                                                      ? Colors.grey
                                                      : Colors.green,
                                                  foregroundColor: Colors.white,
                                                  minimumSize: const Size(
                                                    double.infinity,
                                                    50,
                                                  ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          12,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
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
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
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

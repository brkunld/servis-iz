import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String requestId;
  final String customerId;
  final String technicianId;
  final String companyId;

  const ChatScreen({
    super.key,
    required this.requestId,
    required this.customerId,
    required this.technicianId,
    required this.companyId,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? otherUserName;

  @override
  void initState() {
    super.initState();
    _loadOtherUserName();
  }

  @override
  void dispose() {
    msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadOtherUserName() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    String? otherId;

    try {
      if (currentUser.uid == widget.customerId) {
        otherId = widget.technicianId;
        final doc = await FirebaseFirestore.instance
            .collection("technicians")
            .doc(otherId)
            .get();
        if (doc.exists) {
          setState(() {
            otherUserName = doc.data()?["name"] ?? "Teknisyen";
          });
        }
      } else {
        otherId = widget.customerId;
        final doc = await FirebaseFirestore.instance
            .collection("customers")
            .doc(otherId)
            .get();
        if (doc.exists) {
          setState(() {
            otherUserName = doc.data()?["name"] ?? "Müşteri";
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    if (msgController.text.trim().isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final senderId = currentUser.uid;
    final receiverId = senderId == widget.customerId
        ? widget.technicianId
        : widget.customerId;

    try {
      await FirebaseFirestore.instance.collection("messages").add({
        "requestId": widget.requestId,
        "senderId": senderId,
        "receiverId": receiverId,
        "message": msgController.text.trim(),
        "timestamp": FieldValue.serverTimestamp(),
      });

      msgController.clear();

      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Mesaj gönderilemedi: $e"),
          backgroundColor: Colors.red.shade600,
        ),
      );
    }
  }

  String _formatTime(Timestamp? timestamp) {
    if (timestamp == null) return "";
    final date = timestamp.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return DateFormat('HH:mm').format(date);
    } else if (diff.inDays == 1) {
      return "Dün ${DateFormat('HH:mm').format(date)}";
    } else {
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentUid = currentUser.uid;

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.blue.shade700,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.blue.shade700),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              otherUserName ?? "Sohbet",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("messages")
                  .where("requestId", isEqualTo: widget.requestId)
                  .orderBy("timestamp", descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Colors.blue.shade600,
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      "Bir hata oluştu",
                      style: TextStyle(color: Colors.red.shade600),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Henüz mesaj yok.",
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "İlk mesajı gönderin!",
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data!.docs;

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController.animateTo(
                      _scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final data =
                        msg.data() as Map<String, dynamic>? ??
                        <String, dynamic>{};
                    final bool isMe = data["senderId"] == currentUid;
                    final ts = data["timestamp"];
                    final Timestamp? timestamp = ts is Timestamp ? ts : null;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: isMe
                            ? MainAxisAlignment.end
                            : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (!isMe) ...[
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.blue.shade100,
                              child: Icon(
                                Icons.person,
                                size: 18,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Flexible(
                            child: Column(
                              crossAxisAlignment: isMe
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: isMe
                                        ? LinearGradient(
                                            colors: [
                                              Colors.blue.shade400,
                                              Colors.blue.shade600,
                                            ],
                                          )
                                        : null,
                                    color: isMe ? null : Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: const Radius.circular(18),
                                      topRight: const Radius.circular(18),
                                      bottomLeft: Radius.circular(
                                        isMe ? 18 : 4,
                                      ),
                                      bottomRight: Radius.circular(
                                        isMe ? 4 : 18,
                                      ),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    (data["message"] ?? "").toString(),
                                    style: TextStyle(
                                      color: isMe
                                          ? Colors.white
                                          : Colors.grey.shade800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Text(
                                    _formatTime(timestamp),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (isMe) ...[
                            const SizedBox(width: 8),
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.blue.shade600,
                              child: const Icon(
                                Icons.person,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: msgController,
                        maxLines: null,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: "Mesaj yaz...",
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

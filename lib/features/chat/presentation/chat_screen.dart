import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:mobil_proje/features/auth/data/session_providers.dart';
import 'package:mobil_proje/features/chat/data/chat_repository.dart';
import 'package:mobil_proje/features/customers/data/customer_repository.dart';
import 'package:mobil_proje/features/technicians/data/technician_repository.dart';

/// Talebe bağlı müşteri–teknisyen sohbeti.
class ChatScreen extends ConsumerStatefulWidget {
  final String requestId;
  final String customerId;
  final String technicianId;

  const ChatScreen({
    super.key,
    required this.requestId,
    required this.customerId,
    required this.technicianId,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
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

  /// Karşı tarafın adı: müşteri için teknisyen, teknisyen için müşteri.
  Future<void> _loadOtherUserName() async {
    final uid = ref.read(currentUserIdProvider);
    if (uid == null) return;

    try {
      String? name;
      if (uid == widget.customerId) {
        final tech = await ref
            .read(technicianRepositoryProvider)
            .getTechnician(widget.technicianId);
        if (tech != null) name = tech.name ?? "Teknisyen";
      } else {
        final customer = await ref
            .read(customerRepositoryProvider)
            .getCustomer(widget.customerId);
        if (customer != null) name = customer.name ?? "Müşteri";
      }
      if (name != null && mounted) setState(() => otherUserName = name);
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final text = msgController.text.trim();
    if (text.isEmpty) return;

    final senderId = ref.read(currentUserIdProvider);
    if (senderId == null) return;

    final receiverId = senderId == widget.customerId
        ? widget.technicianId
        : widget.customerId;

    try {
      await ref
          .read(chatRepositoryProvider)
          .send(
            requestId: widget.requestId,
            senderId: senderId,
            receiverId: receiverId,
            message: text,
          );

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

  String _formatTime(DateTime? date) {
    if (date == null) return "";
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
    final currentUid = ref.watch(currentUserIdProvider);
    if (currentUid == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final messagesAsync = ref.watch(chatMessagesProvider(widget.requestId));

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
            child: Builder(
              builder: (context) {
                if (messagesAsync.isLoading && !messagesAsync.hasValue) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: Colors.blue.shade600,
                    ),
                  );
                }

                if (messagesAsync.hasError) {
                  return Center(
                    child: Text(
                      "Bir hata oluştu",
                      style: TextStyle(color: Colors.red.shade600),
                    ),
                  );
                }

                final messages = messagesAsync.valueOrNull ?? const [];
                if (messages.isEmpty) {
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
                    final bool isMe = msg.senderId == currentUid;

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
                                    msg.message,
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
                                    _formatTime(msg.timestamp),
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

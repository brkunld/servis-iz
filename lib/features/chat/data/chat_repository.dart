import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobil_proje/core/firebase/firebase_providers.dart';
import 'package:mobil_proje/features/chat/domain/chat_message.dart';

final chatRepositoryProvider = Provider<ChatRepository>(
  (ref) => ChatRepository(ref.watch(firestoreProvider)),
);

/// `messages` koleksiyonuna erişim.
class ChatRepository {
  ChatRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _messages =>
      _db.collection('messages');

  /// Talebe ait mesajlar, eskiden yeniye.
  Stream<List<ChatMessage>> watchMessages(String requestId) => _messages
      .where('requestId', isEqualTo: requestId)
      .orderBy('timestamp', descending: false)
      .snapshots()
      .map(
        (snap) => [
          for (final d in snap.docs) ChatMessage.fromJson(d.id, d.data()),
        ],
      );

  Future<void> send({
    required String requestId,
    required String senderId,
    required String receiverId,
    required String message,
  }) => _messages.add(
    ChatMessage.createJson(
      requestId: requestId,
      senderId: senderId,
      receiverId: receiverId,
      message: message,
    ),
  );
}

/// Talebin mesajları (sohbet ekranı).
final chatMessagesProvider = StreamProvider.autoDispose
    .family<List<ChatMessage>, String>(
      (ref, requestId) =>
          ref.watch(chatRepositoryProvider).watchMessages(requestId),
    );

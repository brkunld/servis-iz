import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:mobil_proje/core/json/json_read.dart';

/// `messages/{id}` belgesindeki sohbet mesajı. Mesajlar talebe
/// ([requestId]) bağlıdır; yalnız talebin müşterisi ve teknisyeni görür.
@immutable
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.requestId,
    required this.senderId,
    required this.receiverId,
    required this.message,
    this.timestamp,
  });

  final String id;
  final String requestId;
  final String senderId;
  final String receiverId;
  final String message;

  /// Sunucu saati; mesaj yeni gönderildiyse bir an için null olabilir.
  final DateTime? timestamp;

  factory ChatMessage.fromJson(String id, Json json) => ChatMessage(
    id: id,
    requestId: readString(json, 'requestId') ?? '',
    senderId: readString(json, 'senderId') ?? '',
    receiverId: readString(json, 'receiverId') ?? '',
    message: readString(json, 'message') ?? '',
    timestamp: readDateTime(json, 'timestamp'),
  );

  Json toJson() => {
    'requestId': requestId,
    'senderId': senderId,
    'receiverId': receiverId,
    'message': message,
    'timestamp': toTimestamp(timestamp),
  };

  /// Yeni mesaj gönderirken yazılan belge (zaman sunucuda atanır).
  static Json createJson({
    required String requestId,
    required String senderId,
    required String receiverId,
    required String message,
  }) => {
    'requestId': requestId,
    'senderId': senderId,
    'receiverId': receiverId,
    'message': message,
    'timestamp': FieldValue.serverTimestamp(),
  };
}

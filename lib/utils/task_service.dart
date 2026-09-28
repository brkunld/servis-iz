import 'package:cloud_firestore/cloud_firestore.dart';

/// Görev alınamadığında kullanıcıya gösterilecek mesajı taşır.
class TaskException implements Exception {
  final String message;
  const TaskException(this.message);

  @override
  String toString() => message;
}

final _db = FirebaseFirestore.instance;

/// Bekleyen talebi teknisyene atar. Talep ve teknisyen aynı transaction'da
/// güncellenir; iki kişi aynı anda denerse yalnız biri başarılı olur.
/// Teknisyenin kendisi de şirket de bu fonksiyonu kullanır.
Future<void> assignTask({
  required String requestId,
  required String technicianId,
}) {
  final reqRef = _db.collection("requests").doc(requestId);
  final techRef = _db.collection("technicians").doc(technicianId);

  return _db.runTransaction((t) async {
    final req = await t.get(reqRef);
    final tech = await t.get(techRef);

    if (!req.exists ||
        req.data()?["status"] != "Bekliyor" ||
        req.data()?["technicianId"] != null) {
      throw const TaskException("Bu talep artık müsait değil.");
    }
    if (!tech.exists || tech.data()?["active"] == false) {
      throw const TaskException("Teknisyen aktif değil.");
    }
    if (tech.data()?["isAvailable"] == false) {
      throw const TaskException("Teknisyenin devam eden bir görevi var.");
    }

    t.update(reqRef, {
      "technicianId": technicianId,
      "status": "Devam Ediyor",
      "updatedAt": FieldValue.serverTimestamp(),
    });
    t.update(techRef, {"isAvailable": false});
  });
}

/// Görevi tamamlar ve teknisyeni tekrar müsait yapar (tek yazma işlemi).
Future<void> completeTask({
  required String requestId,
  required String technicianId,
}) {
  final batch = _db.batch();
  batch.update(_db.collection("requests").doc(requestId), {
    "status": "Tamamlandı",
    "completedAt": FieldValue.serverTimestamp(),
  });
  batch.update(_db.collection("technicians").doc(technicianId), {
    "isAvailable": true,
  });
  return batch.commit();
}

/// Müşterinin tamamlanan talebi puanlaması. Talep bir kez puanlanabilir;
/// teknisyenin puan ortalaması aynı transaction'da güncellenir.
Future<void> rateTask({
  required String requestId,
  required String technicianId,
  required int stars,
  required String comment,
}) {
  final reqRef = _db.collection("requests").doc(requestId);
  final techRef = _db.collection("technicians").doc(technicianId);

  return _db.runTransaction((t) async {
    final req = await t.get(reqRef);
    final tech = await t.get(techRef);

    if (req.data()?["rated"] == true) {
      throw const TaskException("Bu talep zaten puanlandı.");
    }

    final data = tech.data() ?? {};
    final int totalStars = (data["totalStars"] ?? 0) + stars;
    final int ratingCount = (data["ratingCount"] ?? 0) + 1;

    t.update(reqRef, {
      "rated": true,
      "givenStars": stars,
      "comment": comment,
    });
    t.update(techRef, {
      "totalStars": totalStars,
      "ratingCount": ratingCount,
      "rating": totalStars / ratingCount,
      "lastRatedRequest": requestId,
    });
  });
}

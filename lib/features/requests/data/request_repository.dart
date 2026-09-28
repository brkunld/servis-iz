import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobil_proje/core/firebase/firebase_providers.dart';
import 'package:mobil_proje/features/requests/domain/request_status.dart';
import 'package:mobil_proje/features/requests/domain/service_request.dart';
import 'package:mobil_proje/features/requests/domain/task_exception.dart';
import 'package:mobil_proje/features/technicians/domain/technician.dart';

final requestRepositoryProvider = Provider<RequestRepository>(
  (ref) => RequestRepository(ref.watch(firestoreProvider)),
);

/// `requests` koleksiyonuna erişimin tek kapısı.
///
/// Ekranlar Firestore'u bilmez; talep okumak ya da durumunu değiştirmek
/// için bu sınıfın metotlarını çağırır. Durum değiştiren her metot önce
/// durum makinesine ([RequestStatus.canTransitionTo]) sorar; sunucu tarafında
/// aynı kuralları firestore.rules uygular.
class RequestRepository {
  RequestRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('requests');
  CollectionReference<Map<String, dynamic>> get _technicians =>
      _db.collection('technicians');

  static List<ServiceRequest> _toList(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) => [for (final d in snap.docs) ServiceRequest.fromJson(d.id, d.data())];

  // ---------------------------------------------------------------------------
  // Okuma (canlı akışlar)
  // ---------------------------------------------------------------------------

  /// Müşterinin talepleri, en yeni önce.
  Stream<List<ServiceRequest>> watchCustomerRequests(String customerId) =>
      _requests
          .where('customerId', isEqualTo: customerId)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(_toList);

  /// Tüm talepler (yalnız şirket okuyabilir).
  Stream<List<ServiceRequest>> watchAllRequests() =>
      _requests.snapshots().map(_toList);

  /// Henüz kimsenin almadığı talepler (teknisyen ekranı).
  Stream<List<ServiceRequest>> watchPendingRequests() => _requests
      .where('status', isEqualTo: RequestStatus.pending.value)
      .snapshots()
      .map(_toList);

  /// Teknisyene atanmış tüm talepler.
  Stream<List<ServiceRequest>> watchTechnicianRequests(String technicianId) =>
      _requests
          .where('technicianId', isEqualTo: technicianId)
          .snapshots()
          .map(_toList);

  /// Teknisyenin tamamladığı talepler.
  Stream<List<ServiceRequest>> watchCompletedRequests(String technicianId) =>
      _requests
          .where('technicianId', isEqualTo: technicianId)
          .where('status', isEqualTo: RequestStatus.completed.value)
          .snapshots()
          .map(_toList);

  /// Teknisyenin tamamlanmamış bir görevi var mı?
  Future<bool> hasOpenTask(String technicianId) async {
    final snap = await _requests
        .where('technicianId', isEqualTo: technicianId)
        .where('status', isNotEqualTo: RequestStatus.completed.value)
        .get();
    return snap.docs.isNotEmpty;
  }

  // ---------------------------------------------------------------------------
  // Yazma
  // ---------------------------------------------------------------------------

  Future<void> create(NewServiceRequest request) =>
      _requests.add(request.toCreateJson());

  /// Müşteri yalnız bekleyen talebini silebilir.
  Future<void> deleteByCustomer(ServiceRequest request) {
    if (!request.status.canBeDeletedByCustomer) {
      throw const TaskException('Yalnız bekleyen talepler silinebilir.');
    }
    return _requests.doc(request.id).delete();
  }

  /// Bekliyor → Devam Ediyor. Bekleyen talebi teknisyene atar.
  ///
  /// Talep ve teknisyen aynı transaction'da okunup güncellenir; iki kişi
  /// aynı anda denerse yalnız biri başarılı olur. Teknisyenin kendisi de
  /// şirket de bu metodu kullanır.
  Future<void> assign({
    required String requestId,
    required String technicianId,
  }) {
    final reqRef = _requests.doc(requestId);
    final techRef = _technicians.doc(technicianId);

    return _db.runTransaction((t) async {
      final reqSnap = await t.get(reqRef);
      final techSnap = await t.get(techRef);
      final reqData = reqSnap.data();
      final techData = techSnap.data();

      // Tanınmayan bir durum değeri de "müsait değil" sayılır.
      final status = RequestStatus.tryFromValue(reqData?['status']);
      if (reqData == null ||
          status == null ||
          !status.canTransitionTo(RequestStatus.inProgress) ||
          reqData['technicianId'] != null) {
        throw const TaskException('Bu talep artık müsait değil.');
      }
      if (techData == null) {
        throw const TaskException('Teknisyen aktif değil.');
      }
      final tech = Technician.fromJson(techSnap.id, techData);
      if (!tech.active) {
        throw const TaskException('Teknisyen aktif değil.');
      }
      if (!tech.isAvailable) {
        throw const TaskException('Teknisyenin devam eden bir görevi var.');
      }

      t.update(reqRef, {
        'technicianId': technicianId,
        'status': RequestStatus.inProgress.value,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      t.update(techRef, {'isAvailable': false});
    });
  }

  /// Devam Ediyor → Tamamlandı. Görevi tamamlar ve teknisyeni tekrar müsait
  /// yapar (tek yazma işlemi).
  Future<void> complete(ServiceRequest request) {
    final technicianId = request.technicianId;
    if (!request.status.canTransitionTo(RequestStatus.completed) ||
        technicianId == null) {
      throw InvalidTransitionException(request.status, RequestStatus.completed);
    }

    final batch = _db.batch();
    batch.update(_requests.doc(request.id), {
      'status': RequestStatus.completed.value,
      'completedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_technicians.doc(technicianId), {'isAvailable': true});
    return batch.commit();
  }

  /// Teknisyen devam eden işe kullandığı parçayı ekler.
  Future<void> addPart(ServiceRequest request, String part) {
    _ensurePartsEditable(request);
    return _requests.doc(request.id).update({
      'usedParts': FieldValue.arrayUnion([part]),
    });
  }

  Future<void> removePart(ServiceRequest request, String part) {
    _ensurePartsEditable(request);
    return _requests.doc(request.id).update({
      'usedParts': FieldValue.arrayRemove([part]),
    });
  }

  void _ensurePartsEditable(ServiceRequest request) {
    if (!request.status.canEditParts) {
      throw const TaskException('Parça yalnız devam eden işe eklenebilir.');
    }
  }

  /// Müşterinin tamamlanan talebi puanlaması. Talep bir kez puanlanabilir;
  /// teknisyenin puan ortalaması aynı transaction'da güncellenir.
  Future<void> rate({
    required String requestId,
    required String technicianId,
    required int stars,
    required String comment,
  }) {
    final reqRef = _requests.doc(requestId);
    final techRef = _technicians.doc(technicianId);

    return _db.runTransaction((t) async {
      final reqSnap = await t.get(reqRef);
      final techSnap = await t.get(techRef);

      final request = ServiceRequest.fromJson(reqSnap.id, reqSnap.data() ?? {});
      if (request.rated) {
        throw const TaskException('Bu talep zaten puanlandı.');
      }
      if (!request.status.allowsRating) {
        throw const TaskException('Yalnız tamamlanan talepler puanlanabilir.');
      }

      final tech = Technician.fromJson(techSnap.id, techSnap.data() ?? {});
      final totalStars = tech.totalStars + stars;
      final ratingCount = tech.ratingCount + 1;

      t.update(reqRef, {
        'rated': true,
        'givenStars': stars,
        'comment': comment,
      });
      t.update(techRef, {
        'totalStars': totalStars,
        'ratingCount': ratingCount,
        'rating': totalStars / ratingCount,
        'lastRatedRequest': requestId,
      });
    });
  }
}

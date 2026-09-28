import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobil_proje/features/requests/data/request_repository.dart';
import 'package:mobil_proje/features/requests/domain/request_stats.dart';
import 'package:mobil_proje/features/requests/domain/service_request.dart';

// Ekranların izlediği (ref.watch) talep verileri.
//
// Hepsi `autoDispose`: onu izleyen ekran kapanınca Firestore dinleyicisi de
// kapanır (eski StreamBuilder davranışıyla aynı). `family` ise aynı
// provider'ın parametreyle (ör. müşteri id'si) çağrılmasını sağlar.

/// Müşterinin kendi talepleri (en yeni önce).
final customerRequestsProvider = StreamProvider.autoDispose
    .family<List<ServiceRequest>, String>(
      (ref, customerId) => ref
          .watch(requestRepositoryProvider)
          .watchCustomerRequests(customerId),
    );

/// Tüm talepler (şirket paneli).
final allRequestsProvider = StreamProvider.autoDispose<List<ServiceRequest>>(
  (ref) => ref.watch(requestRepositoryProvider).watchAllRequests(),
);

/// Müşteri başına talep sayıları; tüm talepler akışından hesaplanır.
final requestStatsByCustomerProvider =
    Provider.autoDispose<AsyncValue<Map<String, RequestStats>>>(
      (ref) => ref.watch(allRequestsProvider).whenData(RequestStats.byCustomer),
    );

/// Bekleyen (kimsenin almadığı) talepler.
final pendingRequestsProvider =
    StreamProvider.autoDispose<List<ServiceRequest>>(
      (ref) => ref.watch(requestRepositoryProvider).watchPendingRequests(),
    );

/// Teknisyenin devam eden görevi; yoksa null.
final activeTaskProvider = StreamProvider.autoDispose
    .family<ServiceRequest?, String>(
      (ref, technicianId) => ref
          .watch(requestRepositoryProvider)
          .watchTechnicianRequests(technicianId)
          .map((list) {
            for (final r in list) {
              if (r.status.isOpen) return r;
            }
            return null;
          }),
    );

/// Teknisyenin tamamladığı görevler.
final completedTasksProvider = StreamProvider.autoDispose
    .family<List<ServiceRequest>, String>(
      (ref, technicianId) => ref
          .watch(requestRepositoryProvider)
          .watchCompletedRequests(technicianId),
    );

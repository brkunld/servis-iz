import 'package:flutter/foundation.dart';

import 'request_status.dart';
import 'service_request.dart';

/// Bir müşterinin taleplerinin duruma göre sayıları (şirket panelindeki
/// müşteri kartı için).
@immutable
class RequestStats {
  const RequestStats({
    this.total = 0,
    this.pending = 0,
    this.inProgress = 0,
    this.completed = 0,
  });

  final int total;
  final int pending;
  final int inProgress;
  final int completed;

  factory RequestStats.of(Iterable<ServiceRequest> requests) {
    var pending = 0, inProgress = 0, completed = 0, total = 0;
    for (final r in requests) {
      total++;
      switch (r.status) {
        case RequestStatus.pending:
          pending++;
        case RequestStatus.inProgress:
          inProgress++;
        case RequestStatus.completed:
          completed++;
      }
    }
    return RequestStats(
      total: total,
      pending: pending,
      inProgress: inProgress,
      completed: completed,
    );
  }

  /// Tüm talepleri müşteriye göre gruplayıp her müşteri için sayar.
  static Map<String, RequestStats> byCustomer(
    Iterable<ServiceRequest> requests,
  ) {
    final grouped = <String, List<ServiceRequest>>{};
    for (final r in requests) {
      (grouped[r.customerId] ??= []).add(r);
    }
    return grouped.map((id, list) => MapEntry(id, RequestStats.of(list)));
  }
}

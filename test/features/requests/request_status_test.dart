import 'package:flutter_test/flutter_test.dart';
import 'package:mobil_proje/features/requests/domain/request_status.dart';

void main() {
  group('RequestStatus', () {
    test('Firestore değerleri kurallarla aynı kalır', () {
      // firestore.rules bu dizgelere bağlı; değişirse kurallar da değişmeli.
      expect(RequestStatus.pending.value, 'Bekliyor');
      expect(RequestStatus.inProgress.value, 'Devam Ediyor');
      expect(RequestStatus.completed.value, 'Tamamlandı');
    });

    test('fromValue saklanan değeri çözer', () {
      for (final status in RequestStatus.values) {
        expect(RequestStatus.fromValue(status.value), status);
      }
    });

    test('bilinmeyen ya da boş değer bekleyen sayılır', () {
      expect(RequestStatus.fromValue(null), RequestStatus.pending);
      expect(RequestStatus.fromValue('Atandı'), RequestStatus.pending);
    });

    test('tryFromValue bilinmeyen değerde null döner', () {
      expect(RequestStatus.tryFromValue('Atandı'), isNull);
      expect(RequestStatus.tryFromValue(null), isNull);
      expect(RequestStatus.tryFromValue('Bekliyor'), RequestStatus.pending);
    });
  });

  group('Durum makinesi', () {
    const allowed = {
      (RequestStatus.pending, RequestStatus.inProgress),
      (RequestStatus.inProgress, RequestStatus.completed),
    };

    test('yalnız ileri doğru tek adım geçişe izin verilir', () {
      for (final from in RequestStatus.values) {
        for (final to in RequestStatus.values) {
          expect(
            from.canTransitionTo(to),
            allowed.contains((from, to)),
            reason: '${from.value} → ${to.value}',
          );
        }
      }
    });

    test('her durumda izin verilen işlemler', () {
      expect(RequestStatus.pending.canBeAssigned, isTrue);
      expect(RequestStatus.pending.canBeDeletedByCustomer, isTrue);
      expect(RequestStatus.pending.canBeCompleted, isFalse);
      expect(RequestStatus.pending.canEditParts, isFalse);

      expect(RequestStatus.inProgress.canBeAssigned, isFalse);
      expect(RequestStatus.inProgress.canBeCompleted, isTrue);
      expect(RequestStatus.inProgress.canEditParts, isTrue);
      expect(RequestStatus.inProgress.canTrackTechnician, isTrue);
      expect(RequestStatus.inProgress.canBeDeletedByCustomer, isFalse);

      expect(RequestStatus.completed.isOpen, isFalse);
      expect(RequestStatus.completed.allowsRating, isTrue);
      expect(RequestStatus.completed.canBeCompleted, isFalse);
    });
  });
}

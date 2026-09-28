import 'package:flutter_test/flutter_test.dart';
import 'package:mobil_proje/utils/request_status.dart';

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
  });
}

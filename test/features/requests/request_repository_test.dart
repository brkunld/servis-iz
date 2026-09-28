import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobil_proje/features/requests/data/request_repository.dart';
import 'package:mobil_proje/features/requests/domain/request_status.dart';
import 'package:mobil_proje/features/requests/domain/service_request.dart';
import 'package:mobil_proje/features/requests/domain/task_exception.dart';

/// Repository'nin Firestore'a yazdıklarını sahte (bellek içi) Firestore ile
/// dener. Güvenlik kurallarını denemez; onlar firestore-tests/ altında.
void main() {
  late FakeFirebaseFirestore db;
  late RequestRepository repo;

  Future<Map<String, dynamic>> requestDoc(String id) async =>
      (await db.collection('requests').doc(id).get()).data()!;
  Future<Map<String, dynamic>> techDoc(String id) async =>
      (await db.collection('technicians').doc(id).get()).data()!;

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = RequestRepository(db);

    await db.collection('technicians').doc('t1').set({
      'name': 'Ahmet Usta',
      'active': true,
      'isAvailable': true,
      'totalStars': 9,
      'ratingCount': 2,
    });
    await db.collection('requests').doc('r1').set({
      'customerId': 'c1',
      'status': 'Bekliyor',
      'technicianId': null,
      'rated': false,
    });
  });

  test('yeni talep "Bekliyor" ve atanmamış kaydedilir', () async {
    await repo.create(
      const NewServiceRequest(
        customerId: 'c1',
        customerName: 'Ayşe',
        phone: '0555',
        email: '',
        address: 'Adres',
        issue: 'Arıza',
        floor: '1',
        apartment: '2',
        city: 'Konya',
        district: 'Meram',
      ),
    );
    final list = await repo.watchCustomerRequests('c1').first;
    final created = list.firstWhere((r) => r.id != 'r1');
    expect(created.status, RequestStatus.pending);
    expect(created.technicianId, isNull);
    expect(created.customerName, 'Ayşe');
  });

  group('assign (Bekliyor → Devam Ediyor)', () {
    test('talep atanır, teknisyen meşgul olur', () async {
      await repo.assign(requestId: 'r1', technicianId: 't1');

      final req = await requestDoc('r1');
      expect(req['status'], 'Devam Ediyor');
      expect(req['technicianId'], 't1');
      expect((await techDoc('t1'))['isAvailable'], isFalse);
    });

    test('aynı talep ikinci kez atanamaz', () async {
      await repo.assign(requestId: 'r1', technicianId: 't1');
      await db.collection('technicians').doc('t2').set({'active': true});

      expect(
        () => repo.assign(requestId: 'r1', technicianId: 't2'),
        throwsA(
          isA<TaskException>().having(
            (e) => e.message,
            'message',
            'Bu talep artık müsait değil.',
          ),
        ),
      );
    });

    test('meşgul teknisyene iş atanamaz', () async {
      await db.collection('technicians').doc('t1').update({
        'isAvailable': false,
      });
      expect(
        () => repo.assign(requestId: 'r1', technicianId: 't1'),
        throwsA(isA<TaskException>()),
      );
    });

    test('devre dışı teknisyene iş atanamaz', () async {
      await db.collection('technicians').doc('t1').update({'active': false});
      expect(
        () => repo.assign(requestId: 'r1', technicianId: 't1'),
        throwsA(isA<TaskException>()),
      );
    });
  });

  group('complete (Devam Ediyor → Tamamlandı)', () {
    test('görev tamamlanır, teknisyen boşa çıkar', () async {
      await repo.assign(requestId: 'r1', technicianId: 't1');
      final active = ServiceRequest.fromJson('r1', await requestDoc('r1'));

      await repo.complete(active);

      expect((await requestDoc('r1'))['status'], 'Tamamlandı');
      expect((await techDoc('t1'))['isAvailable'], isTrue);
    });

    test('bekleyen talep doğrudan tamamlanamaz', () async {
      final pending = ServiceRequest.fromJson('r1', await requestDoc('r1'));
      expect(
        () => repo.complete(pending),
        throwsA(isA<InvalidTransitionException>()),
      );
    });
  });

  group('rate', () {
    Future<void> completeR1() async {
      await repo.assign(requestId: 'r1', technicianId: 't1');
      await repo.complete(
        ServiceRequest.fromJson('r1', await requestDoc('r1')),
      );
    }

    test('puan bir kez verilir ve ortalama güncellenir', () async {
      await completeR1();
      await repo.rate(
        requestId: 'r1',
        technicianId: 't1',
        stars: 5,
        comment: 'Teşekkürler',
      );

      final tech = await techDoc('t1');
      expect(tech['totalStars'], 14);
      expect(tech['ratingCount'], 3);
      expect(tech['rating'], closeTo(14 / 3, 1e-9));
      expect(tech['lastRatedRequest'], 'r1');
      expect((await requestDoc('r1'))['givenStars'], 5);

      expect(
        () => repo.rate(
          requestId: 'r1',
          technicianId: 't1',
          stars: 1,
          comment: '',
        ),
        throwsA(isA<TaskException>()),
      );
    });

    test('tamamlanmamış talep puanlanamaz', () async {
      expect(
        () => repo.rate(
          requestId: 'r1',
          technicianId: 't1',
          stars: 5,
          comment: '',
        ),
        throwsA(isA<TaskException>()),
      );
    });
  });

  test('parça yalnız devam eden işe eklenir', () async {
    final pending = ServiceRequest.fromJson('r1', await requestDoc('r1'));
    expect(() => repo.addPart(pending, 'Kayış'), throwsA(isA<TaskException>()));

    await repo.assign(requestId: 'r1', technicianId: 't1');
    final active = ServiceRequest.fromJson('r1', await requestDoc('r1'));
    await repo.addPart(active, 'Kayış');
    expect((await requestDoc('r1'))['usedParts'], ['Kayış']);

    await repo.removePart(active, 'Kayış');
    expect((await requestDoc('r1'))['usedParts'], isEmpty);
  });

  test('hasOpenTask yalnız tamamlanmamış görevi sayar', () async {
    expect(await repo.hasOpenTask('t1'), isFalse);
    await repo.assign(requestId: 'r1', technicianId: 't1');
    expect(await repo.hasOpenTask('t1'), isTrue);
  });
}

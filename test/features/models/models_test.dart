import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobil_proje/core/json/coordinates.dart';
import 'package:mobil_proje/features/chat/domain/chat_message.dart';
import 'package:mobil_proje/features/customers/domain/customer.dart';
import 'package:mobil_proje/features/requests/domain/request_stats.dart';
import 'package:mobil_proje/features/requests/domain/request_status.dart';
import 'package:mobil_proje/features/requests/domain/service_request.dart';
import 'package:mobil_proje/features/technicians/domain/technician.dart';

void main() {
  final created = DateTime(2026, 1, 5, 10, 30);

  group('ServiceRequest', () {
    // tool/seed/seed.js'teki "devam eden" talebin Firestore'daki hâli.
    final json = <String, Object?>{
      'customerId': 'c1',
      'technicianId': 't1',
      'status': 'Devam Ediyor',
      'name': 'Ayşe Yılmaz',
      'phone': '05550000003',
      'email': 'customer@example.com',
      'address': 'Feritpaşa Mah.',
      'issue': 'Çamaşır makinesi sıkma yapmıyor',
      'kat': '3',
      'daire': '12',
      'city': 'Konya',
      'district': 'Selçuklu',
      'location': {'lat': 37.872, 'lng': 32.499},
      'createdAt': Timestamp.fromDate(created),
      'rated': false,
      'givenStars': null,
      'comment': null,
      'usedParts': ['Kayış'],
    };

    test('fromJson Firestore alanlarını okur', () {
      final r = ServiceRequest.fromJson('r1', json);
      expect(r.id, 'r1');
      expect(r.status, RequestStatus.inProgress);
      expect(r.customerName, 'Ayşe Yılmaz');
      expect(r.floor, '3');
      expect(r.apartment, '12');
      expect(r.location, const Coordinates(37.872, 32.499));
      expect(r.createdAt, created);
      expect(r.usedParts, ['Kayış']);
      expect(r.isAssigned, isTrue);
      expect(r.canBeRated, isFalse);
    });

    test('toJson aynı alan adlarıyla geri yazar', () {
      final back = ServiceRequest.fromJson('r1', json).toJson();
      expect(back, json);
    });

    test('eksik ya da hatalı alanlar uygulamayı çökertmez', () {
      final r = ServiceRequest.fromJson('r2', {
        'customerId': 'c1',
        'status': 'Bilinmeyen',
        'location': {'lat': 1}, // lng yok
        'createdAt': null, // serverTimestamp henüz gelmedi
        'givenStars': 4.0,
        'usedParts': 'liste değil',
      });
      expect(r.status, RequestStatus.pending);
      expect(r.location, isNull);
      expect(r.createdAt, isNull);
      expect(r.givenStars, 4);
      expect(r.usedParts, isEmpty);
      expect(r.rated, isFalse);
      expect(r.technicianId, isNull);
    });

    test('tamamlanmış ve puanlanmamış talep puanlanabilir', () {
      final done = ServiceRequest.fromJson('r3', {
        ...json,
        'status': 'Tamamlandı',
      });
      expect(done.canBeRated, isTrue);

      final rated = ServiceRequest.fromJson('r3', {
        ...json,
        'status': 'Tamamlandı',
        'rated': true,
      });
      expect(rated.canBeRated, isFalse);
    });

    test('yeni talep firestore.rules create koşullarına uyar', () {
      const draft = NewServiceRequest(
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
      );
      final data = draft.toCreateJson();
      expect(data['status'], 'Bekliyor');
      expect(data.containsKey('technicianId'), isTrue);
      expect(data['technicianId'], isNull);
      expect(data['rated'], isFalse);
      expect(data['location'], isNull);
      expect(data['createdAt'], isA<FieldValue>());
    });
  });

  group('Coordinates', () {
    test('harita ve GeoPoint biçimlerini okur', () {
      expect(
        Coordinates.tryParse({'lat': 1, 'lng': 2.5}),
        const Coordinates(1, 2.5),
      );
      expect(
        Coordinates.tryParse(const GeoPoint(3, 4)),
        const Coordinates(3, 4),
      );
      expect(Coordinates.tryParse(null), isNull);
      expect(Coordinates.tryParse('37,32'), isNull);
    });
  });

  group('Technician', () {
    test('alan yoksa aktif ve müsait sayılır', () {
      final t = Technician.fromJson('t1', {'name': 'Ahmet Usta'});
      expect(t.active, isTrue);
      expect(t.isAvailable, isTrue);
      expect(t.ratingCount, 0);
      expect(t.rating, isNull);
    });

    test('konumdaki updatedAt alanı konumu bozmaz', () {
      final t = Technician.fromJson('t1', {
        'location': {'lat': 37.8, 'lng': 32.4, 'updatedAt': Timestamp.now()},
        'isAvailable': false,
        'rating': 4.5,
      });
      expect(t.location, const Coordinates(37.8, 32.4));
      expect(t.isAvailable, isFalse);
      expect(t.rating, 4.5);
    });

    test('createJson eski ekranın yazdığı belgeyle aynı', () {
      final data = Technician.createJson(
        name: 'A',
        email: 'a@example.com',
        phone: '0555',
      );
      expect(data.keys, {
        'name',
        'email',
        'phone',
        'rating',
        'ratingCount',
        'totalStars',
        'active',
        'location',
        'isAvailable',
        'createdAt',
      });
      expect(data['active'], isTrue);
      expect(data['isAvailable'], isTrue);
    });
  });

  group('Customer ve ChatMessage', () {
    test('Customer.createJson yalnız kuralların izin verdiği alanlar', () {
      final data = Customer.createJson(name: 'A', email: 'e', phone: 'p');
      expect(data.keys, {'name', 'email', 'phone', 'createdAt'});
    });

    test('ChatMessage gidiş-dönüş', () {
      final json = <String, Object?>{
        'requestId': 'r1',
        'senderId': 'c1',
        'receiverId': 't1',
        'message': 'Merhaba',
        'timestamp': Timestamp.fromDate(created),
      };
      final m = ChatMessage.fromJson('m1', json);
      expect(m.timestamp, created);
      expect(m.toJson(), json);
    });
  });

  group('RequestStats', () {
    ServiceRequest req(String customer, RequestStatus status) =>
        ServiceRequest(id: 'x', customerId: customer, status: status);

    test('müşteriye göre durum sayıları', () {
      final stats = RequestStats.byCustomer([
        req('a', RequestStatus.pending),
        req('a', RequestStatus.completed),
        req('a', RequestStatus.completed),
        req('b', RequestStatus.inProgress),
      ]);
      expect(stats['a']!.total, 3);
      expect(stats['a']!.pending, 1);
      expect(stats['a']!.completed, 2);
      expect(stats['b']!.inProgress, 1);
      expect(stats['c'], isNull);
    });
  });
}

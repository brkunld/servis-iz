import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobil_proje/core/firebase/firebase_providers.dart';
import 'package:mobil_proje/features/customers/domain/customer.dart';

final customerRepositoryProvider = Provider<CustomerRepository>(
  (ref) => CustomerRepository(ref.watch(firestoreProvider)),
);

/// `customers` koleksiyonuna erişim.
class CustomerRepository {
  CustomerRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _customers =>
      _db.collection('customers');

  /// Tüm müşteriler (yalnız şirket okuyabilir).
  Stream<List<Customer>> watchAll() => _customers.snapshots().map(
    (snap) => [for (final d in snap.docs) Customer.fromJson(d.id, d.data())],
  );

  /// Tek müşteriyi okur. Belge yoksa null.
  Future<Customer?> getCustomer(String id) async {
    final snap = await _customers.doc(id).get();
    final data = snap.data();
    return data == null ? null : Customer.fromJson(snap.id, data);
  }

  /// Kayıt olan kullanıcının müşteri belgesini yazar.
  Future<void> create(
    String uid, {
    required String name,
    required String email,
    required String phone,
  }) => _customers
      .doc(uid)
      .set(Customer.createJson(name: name, email: email, phone: phone));
}

/// Tüm müşteriler (şirket paneli).
final customersProvider = StreamProvider.autoDispose<List<Customer>>(
  (ref) => ref.watch(customerRepositoryProvider).watchAll(),
);

/// Tek müşteri, bir kez okunur.
final customerProvider = FutureProvider.autoDispose.family<Customer?, String>(
  (ref, id) => ref.watch(customerRepositoryProvider).getCustomer(id),
);

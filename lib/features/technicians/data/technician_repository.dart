import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobil_proje/core/firebase/emulator.dart';
import 'package:mobil_proje/core/firebase/firebase_providers.dart';
import 'package:mobil_proje/features/technicians/domain/technician.dart';
import 'package:mobil_proje/utils/firebase_options.dart';

final technicianRepositoryProvider = Provider<TechnicianRepository>(
  (ref) => TechnicianRepository(
    ref.watch(firestoreProvider),
    secondaryAuth: _secondaryAuth,
  ),
);

/// Şirket yeni teknisyen hesabı açarken kendi oturumu kapanmasın diye
/// hesap ikinci bir FirebaseApp örneğinde ("adminHelper") açılır.
Future<FirebaseAuth> _secondaryAuth() async {
  const name = 'adminHelper';
  FirebaseApp app;
  try {
    app = Firebase.app(name);
  } on FirebaseException {
    app = await Firebase.initializeApp(
      name: name,
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await connectAuthToEmulator(FirebaseAuth.instanceFor(app: app));
  }
  return FirebaseAuth.instanceFor(app: app);
}

/// `technicians` ve `technicianPhotos` koleksiyonlarına erişim.
class TechnicianRepository {
  TechnicianRepository(this._db, {required this.secondaryAuth});

  final FirebaseFirestore _db;

  /// Teknisyen hesabı açmak için kullanılan ayrı Auth örneği.
  final Future<FirebaseAuth> Function() secondaryAuth;

  CollectionReference<Map<String, dynamic>> get _technicians =>
      _db.collection('technicians');

  static List<Technician> _toList(QuerySnapshot<Map<String, dynamic>> snap) => [
    for (final d in snap.docs) Technician.fromJson(d.id, d.data()),
  ];

  /// Aktif teknisyenler.
  Stream<List<Technician>> watchActive() =>
      _technicians.where('active', isEqualTo: true).snapshots().map(_toList);

  /// Devre dışı bırakılmış teknisyenler.
  Stream<List<Technician>> watchInactive() =>
      _technicians.where('active', isEqualTo: false).snapshots().map(_toList);

  /// Aktif ve şu an boşta olan teknisyenler (atama listesi).
  Stream<List<Technician>> watchAvailable() => _technicians
      .where('active', isEqualTo: true)
      .where('isAvailable', isEqualTo: true)
      .snapshots()
      .map(_toList);

  /// Tek teknisyeni canlı izler (harita). Belge yoksa null.
  Stream<Technician?> watchTechnician(String id) =>
      _technicians.doc(id).snapshots().map((snap) {
        final data = snap.data();
        return data == null ? null : Technician.fromJson(snap.id, data);
      });

  /// Tek teknisyeni bir kez okur. Belge yoksa null.
  Future<Technician?> getTechnician(String id) async {
    final snap = await _technicians.doc(id).get();
    final data = snap.data();
    return data == null ? null : Technician.fromJson(snap.id, data);
  }

  /// Yeni teknisyen hesabı ve belgesi açar; yeni kullanıcının uid'sini
  /// döndürür. Doğrulama e-postası gönderilir.
  Future<String> createTechnician({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final auth = await secondaryAuth();
    final cred = await auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = cred.user!;
    await user.sendEmailVerification();
    await auth.signOut();

    await _technicians
        .doc(user.uid)
        .set(Technician.createJson(name: name, email: email, phone: phone));
    return user.uid;
  }

  /// Şirket teknisyenin adını ve telefonunu günceller.
  Future<void> updateProfile(
    String id, {
    required String name,
    required String phone,
  }) => _technicians.doc(id).update({'name': name, 'phone': phone});

  /// Teknisyeni devre dışı bırakır (silmez) ya da tekrar aktif eder.
  Future<void> setActive(String id, {required bool active}) =>
      _technicians.doc(id).update({
        'active': active,
        'disabledAt': active ? null : FieldValue.serverTimestamp(),
      });

  /// Teknisyenin kendi konumu. Kurallar teknisyenin yalnız `location` ve
  /// `isAvailable` alanlarını değiştirmesine izin verir.
  Future<void> updateLocation(String id, double lat, double lng) =>
      _technicians.doc(id).update({
        'location': {
          'lat': lat,
          'lng': lng,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      });
}

/// Teknisyen profil fotoğrafları Firebase Storage yerine küçük bir JPEG
/// olarak Firestore'da, `technicianPhotos/{technicianId}` belgesinde tutulur.
/// Spark (ücretsiz) planında Storage kullanılamadığı için seçildi; yalnız
/// avatar boyutundaki görseller için uygundur.
class TechnicianPhotoRepository {
  TechnicianPhotoRepository(this._db);

  final FirebaseFirestore _db;

  /// firestore.rules içindeki sınırla aynı olmalı.
  static const int maxPhotoBytes = 200 * 1024;

  DocumentReference<Map<String, dynamic>> _doc(String technicianId) =>
      _db.collection('technicianPhotos').doc(technicianId);

  /// Fotoğraf yoksa null döner.
  Future<Uint8List?> load(String technicianId) async {
    final snap = await _doc(technicianId).get();
    final data = snap.data()?['data'];
    return data is Blob ? data.bytes : null;
  }

  Future<void> save(String technicianId, Uint8List bytes) => _doc(
    technicianId,
  ).set({'data': Blob(bytes), 'updatedAt': FieldValue.serverTimestamp()});
}

final technicianPhotoRepositoryProvider = Provider<TechnicianPhotoRepository>(
  (ref) => TechnicianPhotoRepository(ref.watch(firestoreProvider)),
);

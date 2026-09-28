# Faz 1: Mimari — ne değişti, neden?

Bu belge Faz 1'de yapılan yeniden yapılandırmayı sade bir dille anlatır.
Amaç: kodu kendin anlatabilmen (mülakatta da).

Kısaca: **uygulama aynı çalışıyor, ama kod artık katmanlara ayrıldı.**
Firestore'daki veri, alan adları ve Türkçe durum değerleri (`Bekliyor`,
`Devam Ediyor`, `Tamamlandı`) değişmedi. `firestore.rules` değişmedi.

---

## 1. Eski yapı → yeni yapı

**Eskiden** her ekran her şeyi kendisi yapıyordu:

- Firestore'u doğrudan çağırıyordu (`FirebaseFirestore.instance.collection(...)`).
- Veriyi `data["status"]` gibi ham `Map` olarak okuyordu (107 yerde).
- Girişten sonra hangi ekrana gideceğine kendisi karar veriyordu.
- `company_dashboard.dart` tek başına 2.067 satırdı.

**Şimdi** her işin bir yeri var:

```text
lib/
  main.dart              Firebase'i başlatır, uygulamayı açar
  app.dart               MaterialApp.router + oturum dinleyicisi
  core/                  Özelliklerden bağımsız ortak parçalar
    firebase/            Emülatör ayarı, Firebase provider'ları
    json/                Firestore verisini güvenli okuma, Coordinates
    router/              Adresler, yönlendirme kuralı, go_router
    widgets/             Ortak widget'lar (arka plan)
  features/              Özellik başına klasör (feature-first)
    auth/                Giriş, kayıt, e-posta doğrulama, oturum
    requests/            Servis talepleri (müşteri ekranları)
    technicians/         Teknisyen ekranı, avatar
    company/             Şirket paneli, teknisyen ekle/düzenle
    customers/           Müşteri verisi
    chat/                Sohbet
    tracking/            Canlı takip haritası
```

Her özelliğin içinde aynı üç klasör var:

| Klasör | Ne var? | Örnek |
|---|---|---|
| `domain/` | Model sınıfları, iş kuralları. Firebase'e bağlı değil sayılır. | `ServiceRequest`, `RequestStatus` |
| `data/` | Repository (Firestore erişimi) ve provider'lar | `RequestRepository`, `activeTaskProvider` |
| `presentation/` | Ekranlar ve widget'lar | `TechnicianTaskScreen` |

Kural basit: **ekran → provider → repository → Firestore.** Ekran hiçbir
zaman Firestore'u doğrudan çağırmaz.

Şirket paneli bölündü: `company_dashboard_screen.dart` artık 211 satır ve
yalnız iskeleti tutuyor. Müşteri sekmesi, teknisyen sekmesi ve alt sayfalar
`company/presentation/widgets/` altında ayrı dosyalar.

---

## 2. Katmanlar

### Model sınıfları (`domain/`)

`ServiceRequest`, `Technician`, `Customer`, `ChatMessage`.

- **Ne işe yarar?** Firestore belgesini tipli bir Dart nesnesine çevirir.
  `data["technicianId"]` yerine `request.technicianId` yazarsın.
- **Neden?** Yazım hatası derlemede yakalanır. Alan eksikse ya da tipi
  yanlışsa uygulama çökmez; `fromJson` bunu tek yerde ele alır.
- **Nasıl?** Her sınıfta `fromJson` (Firestore → nesne) ve `toJson`
  (nesne → Firestore) var. Alanlar `final`: nesne değişmez (immutable).
  Değişiklik Firestore'a yazılır, yeni hâli akıştan yeni nesne olarak gelir.
- **Türkçe alanlar:** Firestore'da `kat`, `daire`, `name` olarak kaldı;
  Dart'ta `floor`, `apartment`, `customerName`. Eşleme `fromJson`/`toJson`'da.
- **Neden freezed değil?** freezed kod üretir (`build_runner`, `.g.dart`
  dosyaları). Elle yazılmış sınıf daha az sihirli, satır satır okunabilir.
  Proje büyürse freezed'e geçmek kolay.
- **strict-casts:** `analysis_options.yaml`'da `strict-casts`,
  `strict-inference` ve `strict-raw-types` açık. `dynamic` bir değeri
  sessizce başka tipe çevirmek artık derleme hatası. Modeller veriyi
  `core/json/json_read.dart` içindeki `readString`, `readInt`... ile tip
  kontrol ederek okuduğu için hata kalmadı.

### Repository (`data/*_repository.dart`)

`RequestRepository`, `TechnicianRepository`, `CustomerRepository`,
`ChatRepository`, `AuthRepository`.

- **Ne işe yarar?** Bir koleksiyona erişimin tek kapısı. Okuma
  (`watchPendingRequests()`) ve yazma (`assign()`, `complete()`, `rate()`)
  burada.
- **Neden?** Firestore sorgusu tek yerde olur. Yarın veri kaynağı değişse
  yalnız repository değişir, ekranlar değişmez. Test ederken gerçek
  Firestore yerine sahtesi verilir (`test/.../request_repository_test.dart`
  bunu `fake_cloud_firestore` ile yapıyor).
- Eski `utils/task_service.dart`'taki transaction'lar (görev alma, puanlama)
  aynen `RequestRepository`'ye taşındı.

### Provider (Riverpod)

- **Ne işe yarar?** Ekranın ihtiyaç duyduğu veriyi hazırlar ve ekranı
  günceller. Ekran `ref.watch(activeTaskProvider(uid))` der; veri gelince ya
  da değişince ekran kendiliğinden yeniden çizilir.
- **Neden?** Eskiden iç içe üç `StreamBuilder` vardı. Şimdi her veri bir
  provider; ekranda yalnız `.when(loading:, error:, data:)` kalıyor.
- **Önemli türler:**
  - `Provider`: bir nesne verir (ör. repository).
  - `StreamProvider`: canlı veri (Firestore akışı).
  - `FutureProvider`: bir kez okunan veri (ör. teknisyen adı).
  - `.family`: parametreli provider (`customerRequestsProvider(uid)`).
  - `.autoDispose`: ekranı kimse izlemiyorsa Firestore dinleyicisi kapanır.
- `ref.watch` = izle ve değişince yeniden çiz (build içinde).
  `ref.read` = bir kez oku (buton tıklamasında).

### Router (go_router) ve oturum

- **Ne işe yarar?** Bütün adresler `core/router/app_routes.dart`'ta:
  `/login`, `/customer`, `/technician`, `/company`, `/chat/:requestId`...
- **Oturum:** `sessionProvider` oturumu dört durumdan birine koyar:
  `SignedOut`, `VerificationRequired`, `SignedIn(rol)`, `InvalidSession`.
- **Yönlendirme kuralı:** `authRedirect(oturum, adres)` saf bir
  fonksiyon. Giriş yoksa `/login`'e, doğrulanmamış müşteriyi
  `/verify-email`'e, giriş yapanı rolünün ana ekranına gönderir. Bir rol
  başka rolün adresine giremez (müşteri `/company`'yi açamaz).
- **Neden?** Eskiden giriş ekranı, kayıt ekranı ve `main.dart` ayrı ayrı
  "şimdi hangi ekrana gideyim" diye karar veriyordu. Şimdi karar tek yerde.
  Giriş ekranı yalnız `signIn` çağırır; oturum değişince router gerisini
  yapar.
- Kural saf fonksiyon olduğu için Firebase'siz test edildi
  (`test/core/auth_redirect_test.dart`).

### Talep durum makinesi (`requests/domain/request_status.dart`)

```text
Bekliyor ──ata──▶ Devam Ediyor ──tamamla──▶ Tamamlandı
```

- **Ne işe yarar?** Hangi durumdan hangisine geçilebileceğini söyler:
  `canTransitionTo(next)`. Ayrıca "bu durumda ne yapılabilir?" sorularını
  cevaplar: `canBeAssigned`, `canBeCompleted`, `canEditParts`,
  `canBeDeletedByCustomer`, `allowsRating`.
- **Neden?** Kural eskiden ekranlara dağılmıştı (`status == "Bekliyor"`
  37 yerde). Şimdi tek yerde. Ekran düğmeyi göstermeden önce, repository
  yazmadan önce buna sorar. Sunucu tarafında aynı kuralı `firestore.rules`
  uygular; ikisi birbirini tamamlar.
- Geri gitmek ya da adım atlamak yok. Bunu
  `test/features/requests/request_status_test.dart` tüm durum çiftleri için
  dener.

---

## 3. Bir isteğin yolu: teknisyen "Görevi Al"a basıyor

1. **Ekran** — `technicians/presentation/widgets/available_task_card.dart`:
   düğmenin `onPressed`'i `onTake`'i çağırır.
2. **Ekran durumu** — `technician_task_screen.dart` içindeki `takeTask`:
   ```dart
   await ref.read(requestRepositoryProvider)
       .assign(requestId: request.id, technicianId: uid);
   ```
   `ref.read` ile repository'yi alır. Firestore'u bilmez.
3. **Repository** — `requests/data/request_repository.dart` içindeki
   `assign`: bir **transaction** açar. Talebi ve teknisyeni okur.
4. **Durum makinesi** — transaction içinde sorar:
   `status.canTransitionTo(RequestStatus.inProgress)`. Talep artık
   `Bekliyor` değilse ya da biri almışsa `TaskException("Bu talep artık
   müsait değil.")` fırlatır. Teknisyen devre dışı ya da meşgulse de hata.
5. **Firestore** — her şey uygunsa aynı transaction'da iki yazma:
   talep → `status: "Devam Ediyor"`, `technicianId: uid`;
   teknisyen → `isAvailable: false`. İki teknisyen aynı anda basarsa yalnız
   biri başarılı olur.
6. **Kurallar** — `firestore.rules` yazmayı sunucuda bir kez daha denetler.
7. **Geri dönüş** — Firestore değişince `activeTaskProvider(uid)`
   akışı yeni veriyi yayar. Ekran `ref.watch` ile izlediği için kendiliğinden
   "Aktif Görev" kartına geçer. Kimse `setState` ile listeyi yenilemez.

Hata olursa `takeTask` mesajı yakalar ve SnackBar'da gösterir.

---

## 4. Değişmeyenler (bilerek)

- Firestore koleksiyonları, alan adları, Türkçe durum değerleri.
- Yazılan belgeler aynı (testlerde karşılaştırıldı).
- `firestore.rules` ve kural testleri (38/38 geçiyor).
- Ekranların görünümü. Kod taşındı ve bölündü; renkler, metinler aynı.
- Gizli dosya yeri (`lib/utils/firebase_options.dart`) değişmedi; kurulum
  bozulmasın diye.

Küçük farklar:

- Rolü olmayan hesap giriş yapınca mesaj artık her yerde aynı:
  "Hesabınız bir role bağlı değil. Lütfen tekrar giriş yapın."
- Liste yüklenemezse sonsuz yükleme yerine hata mesajı görünür.
- Şirket panelinde müşteri başına ayrı Firestore dinleyicisi yerine tek
  "tüm talepler" akışı kullanılıyor (daha az okuma).

---

## 5. Testler

```bash
flutter analyze        # temiz olmalı
flutter test           # model, durum makinesi, yönlendirme, repository, kart
cd firestore-tests && npm test   # güvenlik kuralları (emülatör, Java 21)
```

---

## 6. Kendin dene: 3 küçük alıştırma

**Alıştırma 1 — Durum makinesine "İptal Edildi" ekle.**
`request_status.dart`'a `cancelled('İptal Edildi')` ekle. Yalnız
`Bekliyor`'dan geçilebilsin. `flutter analyze` çalıştır: `switch`
kullanan yerler (ör. kartlardaki `statusColor`) eksik durum için hata
verecek; derleyicinin sana yol göstermesini izle. Sonra
`request_status_test.dart`'taki `allowed` kümesine yeni geçişi ekle.
(Not: gerçekten kullanmak için `firestore.rules` da güncellenmeli.)

**Alıştırma 2 — Modele alan ekle.**
`ServiceRequest`'e `String? note` ekle; Firestore'daki adı `not` olsun.
`fromJson`'da `readString(json, 'not')`, `toJson`'da `'not': note`.
`models_test.dart`'taki gidiş-dönüş testine alanı ekleyip testin geçtiğini
gör. Sonra `customer_request_card.dart`'ta notu göster.

**Alıştırma 3 — Yönlendirme kuralını dene.**
`auth_redirect_test.dart`'a bir test yaz: teknisyen `/customer/new-request`
adresine gitmeye çalışınca `/technician`'a gönderilmeli. Testi çalıştır.
Sonra `AppRoutes.allowedPrefixes`'te teknisyene `customer` ekle ve testin
kırıldığını gör (geri almayı unutma). Bu, "rol yetkisi tek yerde"
cümlesinin somut hâli.

---

## 7. Mülakatta 30 saniyede

"Uygulamayı feature-first yapıya taşıdım. Her özellikte domain, data ve
presentation katmanı var. Ekranlar Firestore'u doğrudan çağırmıyor;
repository'den geçiyor ve Riverpod provider'larıyla veriyi izliyor.
Yönlendirme go_router'da, oturum durumuna bakan saf bir fonksiyonla; rol
yetkisi tek yerde. Talep durumu küçük bir durum makinesi; aynı kural
Firestore kurallarında sunucuda da uygulanıyor. Kritik yazmalar
transaction'da. Model, yönlendirme ve repository katmanı Firebase'siz test
ediliyor."

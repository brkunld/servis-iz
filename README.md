# Servisİz

Teknik servis yönetim uygulaması. Mobil Programlama dersi için Flutter ve Firebase ile geliştirildi.
Müşteri, servis şirketi ve teknisyen olmak üzere üç rol vardır:

- **Müşteri:** Kayıt olur, konum seçerek yeni servis talebi açar, taleplerini takip eder ve atanan teknisyenle mesajlaşır.
- **Şirket:** Gelen talepleri panelden yönetir, teknisyen ekler/düzenler ve talepleri teknisyenlere atar.
- **Teknisyen:** Atanan görevleri görür, harita üzerinden müşteri konumuna yol tarifi alır ve görev durumunu günceller.

## Kullanılan teknolojiler

- Flutter / Dart, Riverpod
- Firebase Authentication (e-posta ile giriş), Cloud Firestore (teknisyen fotoğrafları dahil; ücretsiz Spark planında çalışır)
- Google Maps ve flutter_map (OpenStreetMap), geolocator, geocoding

## Kurulum

Gizli yapılandırma dosyaları depoda yoktur. Çalıştırmak için kendi Firebase projenizi bağlayın:

1. `flutter pub get`
2. Firebase projenizi bağlayın: `flutterfire configure` çalıştırın ya da
   `lib/utils/firebase_options.example.dart` dosyasını `lib/utils/firebase_options.dart` adıyla kopyalayıp doldurun.
   Firebase konsolundan indirdiğiniz `google-services.json` dosyasını `android/app/` altına koyun.
3. Google Maps anahtarınızı `android/local.properties` dosyasına ekleyin:
   ```
   MAPS_API_KEY=anahtarınız
   ```
4. `flutter run`



## Yerel geliştirme (Firebase emülatörü)

Gerçek projeye dokunmadan demo verisiyle çalışmak için:

```
firebase emulators:start --project demo-servisiz
cd tool/seed && npm install && npm run seed      # başka bir terminalde
flutter run --dart-define=USE_FIREBASE_EMULATOR=true
```

Demo hesaplar (şifre `demo1234`, yalnız emülatörde):

| Rol | E-posta |
|---|---|
| Şirket | company@example.com |
| Teknisyen | technician@example.com, technician2@example.com |
| Müşteri | customer@example.com |

Gerçek cihazda `--dart-define=EMULATOR_HOST=<bilgisayarın IP adresi>` ekleyin.

## Güvenlik kuralları

Firestore kuralları `firestore.rules` dosyasındadır. Özetle:

- Şirket hesabı yalnız Firebase konsolundan açılır; teknisyeni yalnız şirket ekler. Kimse kendine rol veremez.
- Müşteri kendi kendine kayıt olur. E-postasını doğrulamadan talep açamaz (uygulamada ve kurallarda).
- Teknisyen bekleyen bir işi yalnız müsaitken alabilir. İş ve teknisyen aynı transaction'da güncellenir; iki teknisyen aynı işi alamaz.
- Müşteri tamamlanan işini bir kez, 1-5 yıldız arasında puanlar; teknisyenin puanı yalnız bu puan kadar değişir.
- Mesajları yalnız talebin müşterisi ve atanan teknisyeni okuyup yazabilir.
- Teknisyen fotoğraflarını (en fazla 200 KB) yalnız şirket yükler.

Kuralların testleri Firebase emülatöründe çalışır (Node.js, Firebase CLI ve Java 21+ gerekir):

```
cd firestore-tests
npm install
npm test
```

Kuralları kendi projenize yüklemek için: `firebase deploy --only firestore:rules`

## Geliştirici

Burak Ünaldı

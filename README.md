# Servisİz

Teknik servis yönetim uygulaması. Mobil Programlama dersi için Flutter ve Firebase ile geliştirildi.
Müşteri, servis şirketi ve teknisyen olmak üzere üç rol vardır:

- **Müşteri:** Kayıt olur, konum seçerek yeni servis talebi açar, taleplerini takip eder ve atanan teknisyenle mesajlaşır.
- **Şirket:** Gelen talepleri panelden yönetir, teknisyen ekler/düzenler ve talepleri teknisyenlere atar.
- **Teknisyen:** Atanan görevleri görür, harita üzerinden müşteri konumuna yol tarifi alır ve görev durumunu günceller.

## Kullanılan teknolojiler

- Flutter / Dart, Riverpod
- Firebase Authentication (e-posta ile giriş), Cloud Firestore, Firebase Storage
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

## Geliştirici

Burak Ünaldı

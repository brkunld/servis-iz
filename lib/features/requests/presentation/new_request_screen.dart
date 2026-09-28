import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';

import 'package:mobil_proje/core/json/coordinates.dart';
import 'package:mobil_proje/core/json/json_read.dart';
import 'package:mobil_proje/core/router/app_routes.dart';
import 'package:mobil_proje/core/widgets/app_background.dart';
import 'package:mobil_proje/features/auth/data/session_providers.dart';
import 'package:mobil_proje/features/customers/data/customer_repository.dart';
import 'package:mobil_proje/features/requests/data/request_repository.dart';
import 'package:mobil_proje/features/requests/domain/service_request.dart';
import 'package:mobil_proje/features/requests/presentation/map_picker_screen.dart';

class NewRequestScreen extends ConsumerStatefulWidget {
  const NewRequestScreen({super.key});

  @override
  ConsumerState<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends ConsumerState<NewRequestScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _adSoyadController = TextEditingController();
  final TextEditingController _telefonController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _arizaController = TextEditingController();
  final TextEditingController _adresController = TextEditingController();
  final TextEditingController _katController = TextEditingController();
  final TextEditingController _daireController = TextEditingController();

  String? _selectedCity;
  String? _selectedDistrict;

  /// Haritadan seçilen konum; adres elle girilirse null olur ve konum
  /// gönderirken adresten bulunmaya çalışılır.
  Coordinates? _selectedLocation;

  List<String> _cities = [];
  final Map<String, List<String>> _districts = {};

  @override
  void initState() {
    super.initState();
    loadLocationData();
    Future.delayed(Duration.zero, loadUserInfo);
  }

  @override
  void dispose() {
    for (final c in [
      _adSoyadController,
      _telefonController,
      _emailController,
      _arizaController,
      _adresController,
      _katController,
      _daireController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ✅ HARİTADAN KONUM SEÇİMİ
  Future<void> _openMapPicker() async {
    final result = await context.push<PickedLocation>(AppRoutes.pickLocation);

    if (result != null && mounted) {
      setState(() {
        _adresController.text = result.address;
        _selectedCity = result.city;
        _selectedDistrict = result.district;

        // ⭐ HARİTADAN GELEN KONUM → Direkt kullan
        _selectedLocation = result.coordinates;
      });
    }
  }

  // -----------------------------------------------
  // Kullanıcı bilgileriyle formu önceden doldurma
  // -----------------------------------------------
  Future<void> loadUserInfo() async {
    try {
      final uid = ref.read(currentUserIdProvider);
      if (uid == null) return;

      final customer = await ref
          .read(customerRepositoryProvider)
          .getCustomer(uid);
      if (customer == null || !mounted) return;

      setState(() {
        _adSoyadController.text = customer.name ?? "";
        _emailController.text = customer.email ?? "";
        _telefonController.text = customer.phone ?? "";
      });
    } catch (_) {}
  }

  // -------------------------------------------------------------
  // Şehir ve ilçe JSON'dan yükleme
  // -------------------------------------------------------------
  Future<void> loadLocationData() async {
    final citiesJson = await rootBundle.loadString('assets/sehirler.json');
    final districtsJson = await rootBundle.loadString('assets/ilceler.json');

    final cities = [
      for (final e in json.decode(citiesJson) as List<Object?>) asJson(e)!,
    ];
    final districts = [
      for (final e in json.decode(districtsJson) as List<Object?>) asJson(e)!,
    ];

    // sehir_id → şehir adı
    final cityNames = {
      for (final c in cities) c['sehir_id']: readString(c, 'sehir_adi') ?? '',
    };

    if (!mounted) return;
    setState(() {
      _cities = cityNames.values.toList();

      for (final d in districts) {
        final cityName = cityNames[d['sehir_id']];
        if (cityName == null) continue;
        (_districts[cityName] ??= []).add(readString(d, 'ilce_adi') ?? '');
      }
    });
  }

  // -------------------------------------------------------------
  // ⭐ MANUEL ADRES EKLEME
  // -------------------------------------------------------------
  Future<void> _adresEkle() async {
    final mahalleController = TextEditingController();
    final postaKoduController = TextEditingController();
    final sokakController = TextEditingController();

    String? tempCity = _selectedCity;
    String? tempDistrict = _selectedDistrict;

    final result = await showDialog<String>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialog) {
          return AlertDialog(
            backgroundColor: Colors.grey[200],
            title: const Text("Adres Bilgileri"),
            content: SingleChildScrollView(
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: tempCity,
                    items: _cities
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (val) {
                      setDialog(() {
                        tempCity = val;
                        tempDistrict = null;
                      });
                    },
                    decoration: const InputDecoration(labelText: "Şehir"),
                  ),
                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    initialValue: tempDistrict,
                    items:
                        (tempCity != null
                                ? _districts[tempCity!] ?? <String>[]
                                : <String>[])
                            .map<DropdownMenuItem<String>>(
                              (e) => DropdownMenuItem<String>(
                                value: e,
                                child: Text(e),
                              ),
                            )
                            .toList(),
                    onChanged: (val) {
                      setDialog(() => tempDistrict = val);
                    },
                    decoration: const InputDecoration(labelText: "İlçe"),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: mahalleController,
                    decoration: const InputDecoration(labelText: "Mahalle"),
                  ),
                  const SizedBox(height: 12),

                  const SizedBox(height: 12),

                  TextField(
                    controller: sokakController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: "Açık Adres"),
                  ),
                  const SizedBox(height: 12),

                  TextField(
                    controller: postaKoduController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Posta Kodu"),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("İptal"),
              ),
              ElevatedButton(
                onPressed: () {
                  final fullAddress =
                      "${tempCity ?? ''}, ${tempDistrict ?? ''}, "
                      "${mahalleController.text}, ${postaKoduController.text}, "
                      "${sokakController.text}";

                  setState(() {
                    _adresController.text = fullAddress;
                    _selectedCity = tempCity;
                    _selectedDistrict = tempDistrict;

                    // ⭐ MANUEL ADRES GİRİLDİ → Haritadan gelen koordinatları sıfırla
                    _selectedLocation = null;
                  });

                  Navigator.pop(context, fullAddress);
                },
                child: const Text("Kaydet"),
              ),
            ],
          );
        },
      ),
    );

    if (result != null) {
      setState(() => _adresController.text = result);
    }
  }

  // -------------------------------------------------------------
  // ⭐ FİRESTORE'A TALEP GÖNDERME
  // -------------------------------------------------------------
  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCity == null || _selectedDistrict == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Şehir ve ilçe seçmelisiniz.")),
      );
      return;
    }

    try {
      final uid = ref.read(currentUserIdProvider);
      if (uid == null) return;

      final addressText = _adresController.text.trim();

      var location = _selectedLocation;
      location ??= await _geocode(
        "$addressText $_selectedDistrict $_selectedCity Türkiye",
      );

      await ref
          .read(requestRepositoryProvider)
          .create(
            NewServiceRequest(
              customerId: uid,
              customerName: _adSoyadController.text.trim(),
              phone: _telefonController.text.trim(),
              email: _emailController.text.trim(),
              address: addressText,
              issue: _arizaController.text.trim(),
              floor: _katController.text.trim(),
              apartment: _daireController.text.trim(),
              city: _selectedCity!,
              district: _selectedDistrict!,
              location: location,
            ),
          );

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Talep Gönderildi"),
          content: const Text("Servis talebiniz başarıyla oluşturuldu."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // diyaloğu kapat
                context.pop(); // formdan talepler ekranına dön
              },
              child: const Text("Tamam"),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Hata: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Yeni Talep Oluştur"),
        centerTitle: true,
        backgroundColor: Colors.blue,
      ),
      body: Stack(
        children: [
          const AppBackground(),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                width: size.width > 500 ? 500 : size.width * 0.95,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 8),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildTextField(
                        _adSoyadController,
                        "Ad Soyad",
                        "Örn: Ahmet Yılmaz",
                      ),
                      const SizedBox(height: 12),

                      _buildTextField(
                        _telefonController,
                        "Telefon",
                        "05xx xxx xx xx",
                        isPhone: true,
                      ),
                      const SizedBox(height: 12),

                      _buildTextField(
                        _emailController,
                        "E-posta",
                        "Opsiyonel",
                        isRequired: false,
                      ),
                      const SizedBox(height: 12),

                      Stack(
                        children: [
                          InkWell(
                            onTap: _adresEkle,
                            child: IgnorePointer(
                              child: TextFormField(
                                controller: _adresController,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: "Adres",
                                  hintText: "Adres ekleyin…",
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 12,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          Positioned(
                            right: 8,
                            top: 0,
                            bottom: 0,
                            child: Center(
                              child: IconButton(
                                icon: const Icon(Icons.map, color: Colors.blue),
                                tooltip: "Haritadan Seç",
                                onPressed: _openMapPicker,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _katController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: "Kat",
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return "Kat gerekli";
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _daireController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: "Daire",
                                border: OutlineInputBorder(),
                              ),
                              validator: (val) {
                                if (val == null || val.isEmpty) {
                                  return "Daire gerekli";
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      _buildTextField(
                        _arizaController,
                        "Arıza Açıklaması",
                        "Yaşadığınız sorunu yazın…",
                        maxLines: 3,
                      ),
                      const SizedBox(height: 20),

                      ElevatedButton.icon(
                        onPressed: _submitRequest,
                        icon: const Icon(Icons.send),
                        label: const Text("Talebi Gönder"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 32,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Adresi koordinata çevirir; bulunamazsa null (talep konumsuz kaydedilir).
  Future<Coordinates?> _geocode(String address) async {
    try {
      final result = await locationFromAddress(address);
      if (result.isEmpty) return null;
      return Coordinates(result.first.latitude, result.first.longitude);
    } catch (_) {
      return null;
    }
  }

  Widget _buildTextField(
    TextEditingController c,
    String label,
    String hint, {
    bool isPhone = false,
    int maxLines = 1,
    bool isRequired = true,
  }) {
    return TextFormField(
      controller: c,
      maxLines: maxLines,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      validator: (val) {
        if (!isRequired) return null;
        return (val == null || val.isEmpty) ? "$label boş olamaz" : null;
      },
    );
  }
}

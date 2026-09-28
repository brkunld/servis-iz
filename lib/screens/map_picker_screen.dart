import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng? selectedPosition;
  String selectedAddress = "";
  String selectedCity = "";
  String selectedDistrict = "";

  GoogleMapController? mapController;
  bool isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Konum Seç"),
        backgroundColor: Colors.blue,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(37.8746, 32.4932),
              zoom: 13,
            ),
            onMapCreated: (c) => mapController = c,
            onTap: (LatLng pos) async {
              setState(() {
                selectedPosition = pos;
                isLoading = true;
              });

              try {
                List<Placemark> marks = await placemarkFromCoordinates(
                  pos.latitude,
                  pos.longitude,
                );

                if (marks.isNotEmpty) {
                  final p = marks.first;

                  setState(() {
                    selectedCity = p.administrativeArea ?? "";

                    selectedDistrict =
                        p.subAdministrativeArea ?? p.locality ?? "";

                    List<String> addressParts = [];

                    if (p.subThoroughfare != null &&
                        p.subThoroughfare!.isNotEmpty) {
                      addressParts.add("No: ${p.subThoroughfare}");
                    }

                    if (p.thoroughfare != null && p.thoroughfare!.isNotEmpty) {
                      addressParts.add(p.thoroughfare!);
                    } else if (p.street != null && p.street!.isNotEmpty) {
                      addressParts.add(p.street!);
                    }

                    if (p.subLocality != null && p.subLocality!.isNotEmpty) {
                      addressParts.add("${p.subLocality!} Mah.");
                    }

                    if (p.subAdministrativeArea != null &&
                        p.subAdministrativeArea!.isNotEmpty) {
                      addressParts.add(p.subAdministrativeArea!);
                    } else if (p.locality != null && p.locality!.isNotEmpty) {
                      addressParts.add(p.locality!);
                    }

                    if (p.administrativeArea != null &&
                        p.administrativeArea!.isNotEmpty) {
                      addressParts.add(p.administrativeArea!);
                    }

                    if (p.postalCode != null && p.postalCode!.isNotEmpty) {
                      addressParts.add("PK: ${p.postalCode}");
                    }

                    if (p.country != null && p.country!.isNotEmpty) {
                      addressParts.add(p.country!);
                    }

                    selectedAddress = addressParts.join(", ");
                    isLoading = false;
                  });
                }
              } catch (e) {
                setState(() {
                  selectedAddress = "Adres alınamadı";
                  isLoading = false;
                });
              }
            },
            markers: selectedPosition == null
                ? {}
                : {
                    Marker(
                      markerId: const MarkerId("selected"),
                      position: selectedPosition!,
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueBlue,
                      ),
                    ),
                  },
            myLocationButtonEnabled: true,
            myLocationEnabled: true,
            zoomControlsEnabled: true,
            compassEnabled: true,
          ),

          if (isLoading)
            const Positioned(
              top: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(width: 16),
                        Text("Adres alınıyor..."),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (selectedAddress.isNotEmpty && !isLoading)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.location_on, color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            "Seçilen Konum",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),

                      if (selectedCity.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.location_city,
                                size: 16,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                "$selectedCity ${selectedDistrict.isNotEmpty ? '/ $selectedDistrict' : ''}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.blue,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 8),

                      Text(
                        selectedAddress,
                        style: const TextStyle(fontSize: 14),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              onPressed: (selectedPosition == null || isLoading)
                  ? null
                  : () {
                      if (selectedCity.isEmpty || selectedDistrict.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "Şehir ve ilçe bilgisi alınamadı. Lütfen tekrar deneyin.",
                            ),
                          ),
                        );
                        return;
                      }

                      Navigator.pop(context, {
                        "lat": selectedPosition!.latitude,
                        "lng": selectedPosition!.longitude,
                        "address": selectedAddress,
                        "city": selectedCity,
                        "district": selectedDistrict,
                      });
                    },
              icon: const Icon(Icons.check_circle),
              label: const Text("Bu Konumu Kullan"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

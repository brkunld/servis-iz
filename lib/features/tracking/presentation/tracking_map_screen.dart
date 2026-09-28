import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mobil_proje/core/router/app_routes.dart';
import 'package:mobil_proje/features/technicians/data/technician_providers.dart';
import 'package:mobil_proje/features/technicians/data/technician_repository.dart';
import 'package:mobil_proje/features/technicians/domain/technician.dart';

/// Müşteri adresi ile teknisyenin konumunu aynı haritada gösterir.
///
/// - Müşteri ve şirket: teknisyenin konumunu Firestore'dan canlı izler.
/// - Teknisyen: kendi GPS konumunu gösterir ve Firestore'a yazar.
class TrackingMapScreen extends ConsumerStatefulWidget {
  final MapViewer viewer;
  final String? technicianId;
  final String? customerId;
  final double? customerLat;
  final double? customerLng;

  const TrackingMapScreen({
    super.key,
    required this.viewer,
    this.technicianId,
    this.customerId,
    this.customerLat,
    this.customerLng,
  });

  @override
  ConsumerState<TrackingMapScreen> createState() => _TrackingMapScreenState();
}

class _TrackingMapScreenState extends ConsumerState<TrackingMapScreen> {
  GoogleMapController? mapController;
  StreamSubscription<Technician?>? technicianListener;
  StreamSubscription<Position>? locationStream;

  Uint8List? technicianMarkerIcon;

  LatLng? technicianPosition;
  Position? myCurrentPosition;

  bool loading = true;

  bool get _isTechnician => widget.viewer == MapViewer.technician;

  Future<Uint8List?> _loadPhoto(String technicianId) async {
    try {
      return await ref.read(technicianPhotoProvider(technicianId).future);
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _createCircularMarker(Uint8List rawImage, int size) async {
    final codec = await instantiateImageCodec(
      rawImage,
      targetWidth: size,
      targetHeight: size,
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..isAntiAlias = true;

    final radius = size / 2;

    canvas.drawCircle(Offset(radius, radius), radius, paint);

    paint.blendMode = BlendMode.srcIn;
    canvas.drawImage(image, Offset.zero, paint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size, size);
    final pngBytes = await img.toByteData(format: ImageByteFormat.png);
    return pngBytes?.buffer.asUint8List();
  }

  Future<void> _loadTechnicianMarker() async {
    try {
      if (widget.technicianId == null) return;

      final rawImage = await _loadPhoto(widget.technicianId!);
      if (rawImage == null) return;

      final circle = await _createCircularMarker(rawImage, 120);
      if (circle == null) return;

      if (mounted) {
        setState(() {
          technicianMarkerIcon = circle;
        });
      }
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _initialize() {
    if (_isTechnician) {
      _getCurrentLocationAndStartTracking();
    } else {
      _listenTechnicianLocation();
    }
  }

  void _listenTechnicianLocation() {
    final technicianId = widget.technicianId;
    if (technicianId == null) {
      loading = false;
      return;
    }

    technicianListener = ref
        .read(technicianRepositoryProvider)
        .watchTechnician(technicianId)
        .listen((technician) {
          final location = technician?.location;

          if (location != null) {
            if (mounted) {
              setState(() {
                technicianPosition = LatLng(location.lat, location.lng);
                loading = false;
              });
            }

            if (technicianMarkerIcon == null) {
              _loadTechnicianMarker();
            }

            Future.microtask(_updateCameraToShowBoth);
          } else {
            if (mounted) setState(() => loading = false);
          }
        });
  }

  Future<void> _getCurrentLocationAndStartTracking() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Lütfen konum servisini açınız.')),
          );
          setState(() => loading = false);
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => loading = false);
        return;
      }

      myCurrentPosition = await Geolocator.getCurrentPosition();
      if (mounted) setState(() => loading = false);

      _startLocationUpdateToFirebase();
      unawaited(Future.microtask(_updateCameraToShowBoth));
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  void _startLocationUpdateToFirebase() {
    final technicianId = widget.technicianId;
    if (technicianId == null) return;
    final technicians = ref.read(technicianRepositoryProvider);

    locationStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 20,
          ),
        ).listen((Position position) {
          if (mounted) {
            setState(() {
              myCurrentPosition = position;
            });
          }

          technicians
              .updateLocation(
                technicianId,
                position.latitude,
                position.longitude,
              )
              .catchError((Object e) => debugPrint("Konum yazılamadı: $e"));

          Future.microtask(_updateCameraToShowBoth);
        });
  }

  LatLng? _customerLatLng() {
    if (widget.customerLat == null || widget.customerLng == null) return null;
    return LatLng(widget.customerLat!, widget.customerLng!);
  }

  LatLng? _technicianLatLng() {
    if (_isTechnician) {
      if (myCurrentPosition == null) return null;
      return LatLng(myCurrentPosition!.latitude, myCurrentPosition!.longitude);
    }
    return technicianPosition;
  }

  void _updateCameraToShowBoth() {
    if (mapController == null) return;

    final customer = _customerLatLng();
    final tech = _technicianLatLng();

    if (customer == null && tech == null) return;

    if (customer != null && tech == null) {
      mapController!.animateCamera(CameraUpdate.newLatLngZoom(customer, 15));
      return;
    }

    if (tech != null && customer == null) {
      mapController!.animateCamera(CameraUpdate.newLatLngZoom(tech, 15));
      return;
    }

    final c = customer!;
    final t = tech!;

    if ((c.latitude - t.latitude).abs() < 0.0001 &&
        (c.longitude - t.longitude).abs() < 0.0001) {
      mapController!.animateCamera(CameraUpdate.newLatLngZoom(c, 17));
      return;
    }

    final double minLat = c.latitude < t.latitude ? c.latitude : t.latitude;
    final double maxLat = c.latitude > t.latitude ? c.latitude : t.latitude;
    final double minLng = c.longitude < t.longitude ? c.longitude : t.longitude;
    final double maxLng = c.longitude > t.longitude ? c.longitude : t.longitude;

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  Future<void> _openNavigation() async {
    final customer = _customerLatLng();
    if (customer == null) return;

    final lat = customer.latitude;
    final lng = customer.longitude;

    final Uri googleMapsUrl = Uri.parse("google.navigation:q=$lat,$lng&mode=d");
    final Uri webUrl = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=$lat,$lng",
    );

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl);
      } else {
        await launchUrl(webUrl, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    final customer = _customerLatLng();
    if (customer != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('customer'),
          position: customer,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(
            title: 'Müşteri Adresi',
            snippet: 'Arıza Konumu',
          ),
        ),
      );
    }

    final tech = _technicianLatLng();
    if (tech != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('technician'),
          position: tech,
          icon: technicianMarkerIcon != null
              ? BitmapDescriptor.bytes(technicianMarkerIcon!)
              : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(
            title: 'Teknisyen',
            snippet: 'Güncel Konum',
          ),
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _buildPolylines() {
    final customer = _customerLatLng();
    final tech = _technicianLatLng();

    if (customer == null || tech == null) return {};

    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: [customer, tech],
        color: Colors.blue.shade700,
        width: 5,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    };
  }

  Color _getAppBarColor() => Colors.blue.shade700;

  String _getTitle() => switch (widget.viewer) {
    MapViewer.technician => 'Müşteriye Git',
    MapViewer.company => 'Canlı Takip (Admin)',
    MapViewer.customer => 'Teknisyen Takibi',
  };

  @override
  void dispose() {
    technicianListener?.cancel();
    locationStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initial =
        _customerLatLng() ?? _technicianLatLng() ?? const LatLng(39.0, 35.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(_getTitle()),
        backgroundColor: _getAppBarColor(),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.zoom_out_map),
            onPressed: _updateCameraToShowBoth,
            tooltip: "Sığdır",
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: initial, zoom: 14),
            onMapCreated: (controller) {
              mapController = controller;
              Future.microtask(_updateCameraToShowBoth);
            },
            markers: _buildMarkers(),
            polylines: _buildPolylines(),
            myLocationEnabled: _isTechnician,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: false,
          ),

          if (loading)
            Center(
              child: Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 10),
                      Text(
                        _isTechnician
                            ? 'GPS Konumu Bekleniyor...'
                            : 'Teknisyen Konumu Bekleniyor...',
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (_isTechnician && !loading && _customerLatLng() != null)
            Positioned(
              bottom: 20,
              left: MediaQuery.of(context).size.width * 0.05,
              width: MediaQuery.of(context).size.width * 0.9,
              child: FloatingActionButton.extended(
                onPressed: _openNavigation,
                label: const Text('Yol Tarifi Al'),
                icon: const Icon(Icons.directions),
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

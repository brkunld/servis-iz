import 'dart:typed_data';
import 'dart:ui';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

class UniversalMapScreen extends StatefulWidget {
  final String userType;
  final String? technicianId;
  final String? customerId;
  final double? customerLat;
  final double? customerLng;

  const UniversalMapScreen({
    super.key,
    required this.userType,
    this.technicianId,
    this.customerId,
    this.customerLat,
    this.customerLng,
  });

  @override
  State<UniversalMapScreen> createState() => _UniversalMapScreenState();
}

class _UniversalMapScreenState extends State<UniversalMapScreen> {
  GoogleMapController? mapController;
  StreamSubscription<DocumentSnapshot>? technicianListener;
  StreamSubscription<Position>? locationStream;

  Uint8List? technicianMarkerIcon;

  LatLng? technicianPosition;
  Position? myCurrentPosition;

  bool loading = true;

  Future<Uint8List?> _loadTechnicianImageFromStorage(String technicianId) async {
    try {
      final ref = FirebaseStorage.instance.ref("technicians/$technicianId.jpg");
      final data = await ref.getData();
      return data;
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

      final rawImage = await _loadTechnicianImageFromStorage(widget.technicianId!);
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
    if (widget.userType == 'customer' || widget.userType == 'admin') {
      _listenTechnicianLocation();
    } else if (widget.userType == 'technician') {
      _getCurrentLocationAndStartTracking();
    } else {
      // fallback
      setState(() => loading = false);
    }
  }

  void _listenTechnicianLocation() {
    if (widget.technicianId == null) {
      setState(() => loading = false);
      return;
    }

    technicianListener = FirebaseFirestore.instance
        .collection('technicians')
        .doc(widget.technicianId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) {
        if (mounted) setState(() => loading = false);
        return;
      }

      final data = snapshot.data();
      final locationAny = data?['location'];

      double? lat;
      double? lng;

      if (locationAny is Map) {
        if (locationAny['lat'] != null && locationAny['lng'] != null) {
          lat = (locationAny['lat'] as num).toDouble();
          lng = (locationAny['lng'] as num).toDouble();
        }
      } else if (locationAny is GeoPoint) {
        lat = locationAny.latitude;
        lng = locationAny.longitude;
      }

      if (lat != null && lng != null) {
        if (mounted) {
          setState(() {
            technicianPosition = LatLng(lat!, lng!);
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
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
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
      Future.microtask(_updateCameraToShowBoth);
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  void _startLocationUpdateToFirebase() {
    if (widget.technicianId == null) return;

    locationStream = Geolocator.getPositionStream(
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

      FirebaseFirestore.instance
          .collection('technicians')
          .doc(widget.technicianId)
          .set({
        'location': {
          'lat': position.latitude,
          'lng': position.longitude,
          'updatedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));

      Future.microtask(_updateCameraToShowBoth);
    });
  }

  LatLng? _customerLatLng() {
    if (widget.customerLat == null || widget.customerLng == null) return null;
    return LatLng(widget.customerLat!, widget.customerLng!);
  }

  LatLng? _technicianLatLng() {
    if (widget.userType == 'technician') {
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

    double minLat = c.latitude < t.latitude ? c.latitude : t.latitude;
    double maxLat = c.latitude > t.latitude ? c.latitude : t.latitude;
    double minLng = c.longitude < t.longitude ? c.longitude : t.longitude;
    double maxLng = c.longitude > t.longitude ? c.longitude : t.longitude;

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
              ? BitmapDescriptor.fromBytes(technicianMarkerIcon!)
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
        patterns: [
          PatternItem.dash(20),
          PatternItem.gap(10),
        ],
      ),
    };
  }

  Color _getAppBarColor() => Colors.blue.shade700;

  String _getTitle() {
    if (widget.userType == 'technician') return 'Müşteriye Git';
    if (widget.userType == 'admin') return 'Canlı Takip (Admin)';
    return 'Teknisyen Takibi';
  }

  @override
  void dispose() {
    technicianListener?.cancel();
    locationStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initial = _customerLatLng() ?? _technicianLatLng() ?? const LatLng(39.0, 35.0);

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
            initialCameraPosition: CameraPosition(
              target: initial,
              zoom: 14,
            ),
            onMapCreated: (controller) {
              mapController = controller;
              Future.microtask(_updateCameraToShowBoth);
            },
            markers: _buildMarkers(),
            polylines: _buildPolylines(),
            myLocationEnabled: widget.userType == 'technician',
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
                        widget.userType == 'technician'
                            ? 'GPS Konumu Bekleniyor...'
                            : 'Teknisyen Konumu Bekleniyor...',
                      ),
                    ],
                  ),
                ),
              ),
            ),

          if (widget.userType == 'technician' && !loading && _customerLatLng() != null)
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

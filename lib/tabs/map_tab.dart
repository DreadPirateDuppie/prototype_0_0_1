import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  late GoogleMapController mapController;
  Set<Marker> markers = {};
  bool _isLoading = true;

  final CameraPosition _initialPosition = const CameraPosition(
    target: LatLng(37.7749, -122.4194), // San Francisco
    zoom: 14.0,
  );

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _addSampleMarkers();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 100,
        ),
      );

      if (mounted) {
        final newPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 14.0,
        );

        mapController.animateCamera(
          CameraUpdate.newCameraPosition(newPosition),
        );

        setState(() {
          _isLoading = false;
        });

        // Add marker at current location
        _addMarker(
          position.latitude,
          position.longitude,
          'Your Location',
          'You are here',
          BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }

  void _addSampleMarkers() {
    // Add some sample markers around San Francisco
    _addMarker(
      37.7749,
      -122.4194,
      'Downtown SF',
      'City Center',
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    );
    _addMarker(
      37.8044,
      -122.2712,
      'Golden Gate Bridge',
      'Famous landmark',
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
    );
    _addMarker(
      37.7694,
      -122.4862,
      'Ocean Beach',
      'Beautiful beach',
      BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    );
  }

  void _addMarker(
    double latitude,
    double longitude,
    String title,
    String snippet,
    BitmapDescriptor icon,
  ) {
    final marker = Marker(
      markerId: MarkerId('${latitude}_$longitude'),
      position: LatLng(latitude, longitude),
      infoWindow: InfoWindow(title: title, snippet: snippet),
      icon: icon,
    );

    setState(() {
      markers.add(marker);
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition: _initialPosition,
          markers: markers,
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: true,
          compassEnabled: true,
        ),
        if (_isLoading)
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }
}


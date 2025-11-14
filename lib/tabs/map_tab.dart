import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class MapTab extends StatefulWidget {
  const MapTab({super.key});

  @override
  State<MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<MapTab> {
  late GoogleMapController mapController;

  final CameraPosition _initialPosition = const CameraPosition(
    target: LatLng(37.7749, -122.4194), // San Francisco
    zoom: 14.0,
  );

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return GoogleMap(
      onMapCreated: _onMapCreated,
      initialCameraPosition: _initialPosition,
    );
  }

  @override
  void dispose() {
    mapController.dispose();
    super.dispose();
  }
}

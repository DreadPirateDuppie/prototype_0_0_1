import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

class NavigationProvider extends ChangeNotifier {
  int _selectedIndex = 2; // Map is default screen
  LatLng? _targetLocation;

  int get selectedIndex => _selectedIndex;
  LatLng? get targetLocation => _targetLocation;

  void setIndex(int index, {LatLng? targetLocation}) {
    if (_selectedIndex != index) {
      _selectedIndex = index;
      _targetLocation = targetLocation;
      notifyListeners();
    } else if (targetLocation != null) {
      // Same tab but new location
      _targetLocation = targetLocation;
      notifyListeners();
    }
  }

  void clearTargetLocation() {
    _targetLocation = null;
  }
}

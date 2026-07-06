import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/borough.dart';

/// Renders borough turf polygons for the Territorial Capture system.
///
/// * Owned boroughs are filled with the owning crew's colour; the fill
///   opacity fades as destabilization rises (the "Fragile State" indicator
///   visible to rivals). A fully destabilized borough is nearly transparent
///   with a red border — ready to flip.
/// * Unowned boroughs get a faint neutral outline so turf lines are visible.
class TerritoryPolygonLayer extends StatelessWidget {
  final List<BoroughState> boroughs;

  const TerritoryPolygonLayer({super.key, required this.boroughs});

  /// Parse a `#RRGGBB` hex string into a [Color]; falls back to matrix green.
  static Color parseCrewColor(String? hex) {
    const fallback = Color(0xFF00FF41);
    if (hex == null) return fallback;
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length != 6) return fallback;
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return fallback;
    return Color(0xFF000000 | value);
  }

  @override
  Widget build(BuildContext context) {
    final polygons = <Polygon>[];

    for (final borough in boroughs) {
      if (borough.polygon.length < 3) continue;

      if (borough.isOwned) {
        final crewColor = parseCrewColor(borough.owningCrewColorHex);
        final capturable = borough.isCapturable;
        polygons.add(
          Polygon(
            points: borough.polygon,
            color: crewColor.withValues(alpha: borough.fillOpacity),
            borderColor: capturable
                ? Colors.red
                : crewColor.withValues(alpha: 0.8),
            borderStrokeWidth: capturable ? 2.5 : 1.5,
          ),
        );
      } else {
        polygons.add(
          Polygon(
            points: borough.polygon,
            color: Colors.white.withValues(alpha: 0.02),
            borderColor: Colors.white.withValues(alpha: 0.15),
            borderStrokeWidth: 1.0,
          ),
        );
      }
    }

    if (polygons.isEmpty) return const SizedBox.shrink();
    return PolygonLayer(polygons: polygons);
  }
}

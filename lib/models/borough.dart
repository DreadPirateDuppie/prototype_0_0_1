import 'package:latlong2/latlong.dart';

/// Live state of one borough turf zone, as returned by the `borough_states`
/// Supabase view (Territorial Capture system).
class BoroughState {
  final String boroughId;
  final String name;

  /// Simplified boundary ring as [lat, lng] vertices (closed implicitly).
  final List<LatLng> polygon;

  final String? owningCrewId;
  final String? owningCrewName;

  /// Owning crew colour as `#RRGGBB`; null when unowned.
  final String? owningCrewColorHex;

  final double defenseScore;
  final double destabilizationScore;
  final DateTime? lastCapturedAt;

  BoroughState({
    required this.boroughId,
    required this.name,
    required this.polygon,
    this.owningCrewId,
    this.owningCrewName,
    this.owningCrewColorHex,
    this.defenseScore = 0.0,
    this.destabilizationScore = 0.0,
    this.lastCapturedAt,
  });

  bool get isOwned => owningCrewId != null;

  /// "Fragile State" indicator: 0.0 = fully stable, 1.0 = ready to flip.
  double get fragility {
    if (defenseScore <= 0) return destabilizationScore > 0 ? 1.0 : 0.0;
    return (destabilizationScore / defenseScore).clamp(0.0, 1.0);
  }

  /// Fully destabilized: the next qualifying rival-crew activity captures it.
  bool get isCapturable => fragility >= 1.0;

  /// Polygon fill opacity for the map layer: fades from [maxOpacity] down to
  /// [minOpacity] as destabilization rises (Fragile State visual).
  static double fillOpacityFor(
    double fragility, {
    double maxOpacity = 0.35,
    double minOpacity = 0.05,
  }) {
    final f = fragility.clamp(0.0, 1.0);
    return maxOpacity - (maxOpacity - minOpacity) * f;
  }

  double get fillOpacity => fillOpacityFor(fragility);

  factory BoroughState.fromMap(Map<String, dynamic> map) {
    final rawPolygon = map['polygon'];
    final points = <LatLng>[];
    if (rawPolygon is List) {
      for (final vertex in rawPolygon) {
        if (vertex is List && vertex.length >= 2) {
          final lat = (vertex[0] as num?)?.toDouble();
          final lng = (vertex[1] as num?)?.toDouble();
          if (lat != null && lng != null) {
            points.add(LatLng(lat, lng));
          }
        }
      }
    }

    return BoroughState(
      boroughId: map['borough_id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      polygon: points,
      owningCrewId: map['owning_crew_id'] as String?,
      owningCrewName: map['owning_crew_name'] as String?,
      owningCrewColorHex: map['owning_crew_color'] as String?,
      defenseScore: (map['defense_score'] as num?)?.toDouble() ?? 0.0,
      destabilizationScore:
          (map['destabilization_score'] as num?)?.toDouble() ?? 0.0,
      lastCapturedAt: map['last_captured_at'] != null
          ? DateTime.tryParse(map['last_captured_at'].toString())
          : null,
    );
  }
}

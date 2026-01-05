class GhostLine {
  final String id;
  final String spotId;
  final String creatorId;
  final String videoUrl;
  final String? thumbnailUrl;
  final List<GhostPathPoint> pathPoints;
  final List<GhostTrickMarker> trickMarkers;
  final int? durationSeconds;
  final double? distanceMeters;
  final DateTime createdAt;

  GhostLine({
    required this.id,
    required this.spotId,
    required this.creatorId,
    required this.videoUrl,
    this.thumbnailUrl,
    required this.pathPoints,
    this.trickMarkers = const [],
    this.durationSeconds,
    this.distanceMeters,
    required this.createdAt,
  });

  factory GhostLine.fromMap(Map<String, dynamic> map) {
    return GhostLine(
      id: map['id'] as String,
      spotId: map['spot_id'] as String,
      creatorId: map['creator_id'] as String,
      videoUrl: map['video_url'] as String,
      thumbnailUrl: map['thumbnail_url'] as String?,
      pathPoints: (map['path_points'] as List<dynamic>)
          .map((e) => GhostPathPoint.fromMap(e as Map<String, dynamic>))
          .toList(),
      trickMarkers: (map['trick_markers'] as List<dynamic>?)
              ?.map((e) => GhostTrickMarker.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      durationSeconds: (map['duration_seconds'] as num?)?.toInt(),
      distanceMeters: (map['distance_meters'] as num?)?.toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'spot_id': spotId,
      'creator_id': creatorId,
      'video_url': videoUrl,
      'thumbnail_url': thumbnailUrl,
      'path_points': pathPoints.map((e) => e.toMap()).toList(),
      'trick_markers': trickMarkers.map((e) => e.toMap()).toList(),
      'duration_seconds': durationSeconds,
      'distance_meters': distanceMeters,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class GhostPathPoint {
  final double latitude;
  final double longitude;
  final int timestamp; // Milliseconds from start

  GhostPathPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  factory GhostPathPoint.fromMap(Map<String, dynamic> map) {
    return GhostPathPoint(
      latitude: (map['lat'] as num).toDouble(),
      longitude: (map['lng'] as num).toDouble(),
      timestamp: (map['ts'] as num).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lat': latitude,
      'lng': longitude,
      'ts': timestamp,
    };
  }
}

class GhostTrickMarker {
  final double latitude;
  final double longitude;
  final String trickName;
  final int timestamp;

  GhostTrickMarker({
    required this.latitude,
    required this.longitude,
    required this.trickName,
    required this.timestamp,
  });

  factory GhostTrickMarker.fromMap(Map<String, dynamic> map) {
    return GhostTrickMarker(
      latitude: (map['lat'] as num).toDouble(),
      longitude: (map['lng'] as num).toDouble(),
      trickName: map['trick'] as String,
      timestamp: (map['ts'] as num).toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lat': latitude,
      'lng': longitude,
      'trick': trickName,
      'ts': timestamp,
    };
  }
}

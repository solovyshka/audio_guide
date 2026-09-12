class LatLon {
  const LatLon({required this.lat, required this.lon});

  final double lat;
  final double lon;

  factory LatLon.fromJson(Map<String, dynamic> json) {
    return LatLon(
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
    );
  }
}

class GuideSummary {
  const GuideSummary({
    required this.id,
    required this.title,
    this.subtitle,
    required this.city,
    required this.stopsCount,
    required this.durationSec,
    required this.contentVersion,
    required this.center,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String city;
  final int stopsCount;
  final int durationSec;
  final int contentVersion;
  final LatLon center;

  factory GuideSummary.fromJson(Map<String, dynamic> json) {
    return GuideSummary(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      city: json['city'] as String? ?? json['title'] as String,
      stopsCount: (json['stopsCount'] ?? json['stops_count'] ?? 0) as int,
      durationSec: (json['durationSec'] ?? json['duration_sec'] ?? 0) as int,
      contentVersion:
          (json['contentVersion'] ?? json['content_version'] ?? 1) as int,
      center: LatLon.fromJson(json['center'] as Map<String, dynamic>),
    );
  }
}

class Track {
  const Track({
    required this.title,
    required this.text,
    this.audioUrl,
    required this.durationSec,
  });

  final String title;
  final String text;
  final String? audioUrl;
  final int durationSec;

  factory Track.fromJson(Map<String, dynamic> json) {
    return Track(
      title: (json['title'] ?? json['name'] ?? '') as String,
      text: json['text'] as String? ?? '',
      audioUrl: (json['audioUrl'] ?? json['audio_url']) as String?,
      durationSec: (json['durationSec'] ?? json['duration_sec'] ?? 0) as int,
    );
  }
}

class Stop extends Track {
  const Stop({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.order,
    this.category,
    required super.title,
    required super.text,
    super.audioUrl,
    required super.durationSec,
  });

  final String id;
  final String name;
  final double lat;
  final double lon;
  final int order;
  final String? category;

  factory Stop.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String;
    return Stop(
      id: json['id'] as String,
      name: name,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      order: (json['order'] ?? 0) as int,
      category: json['category'] as String?,
      title: name,
      text: json['text'] as String? ?? '',
      audioUrl: (json['audioUrl'] ?? json['audio_url']) as String?,
      durationSec: (json['durationSec'] ?? json['duration_sec'] ?? 0) as int,
    );
  }
}

class Guide extends GuideSummary {
  const Guide({
    required super.id,
    required super.title,
    super.subtitle,
    required super.city,
    required super.stopsCount,
    required super.durationSec,
    required super.contentVersion,
    required super.center,
    required this.intro,
    required this.stops,
  });

  final Track intro;
  final List<Stop> stops;

  factory Guide.fromJson(Map<String, dynamic> json) {
    final stops = (json['stops'] as List<dynamic>)
        .map((item) => Stop.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return Guide(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      city: json['city'] as String? ?? json['title'] as String,
      stopsCount: stops.length,
      durationSec: (json['durationSec'] ?? json['duration_sec'] ?? 0) as int,
      contentVersion:
          (json['contentVersion'] ?? json['content_version'] ?? 1) as int,
      center: LatLon.fromJson(json['center'] as Map<String, dynamic>),
      intro: Track.fromJson(json['intro'] as Map<String, dynamic>),
      stops: stops,
    );
  }

  List<Track> get playlist => [intro, ...stops];
}

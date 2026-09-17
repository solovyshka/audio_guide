import '../config.dart';

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
    this.mapUrl,
    this.mapBounds,
  });

  final Track intro;
  final List<Stop> stops;
  final String? mapUrl;
  final MapBounds? mapBounds;

  bool get hasSnapshot => mapUrl != null && mapUrl!.isNotEmpty;

  MapBounds get bounds => mapBounds ?? MapBounds.fromStops(stops);

  factory Guide.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final stops = (json['stops'] as List<dynamic>)
        .map((item) => Stop.fromJson(item as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    final rawBounds = json['mapBounds'] ?? json['map_bounds'];
    return Guide(
      id: id,
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
      mapUrl: (json['mapUrl'] ?? json['map_url']) as String? ??
          '$apiBase/guides/$id/map.png',
      mapBounds: rawBounds is Map<String, dynamic>
          ? MapBounds.fromJson(rawBounds)
          : null,
    );
  }

  List<Track> get playlist => [intro, ...stops];
}

class MapBounds {
  const MapBounds({
    required this.latMin,
    required this.latMax,
    required this.lonMin,
    required this.lonMax,
    this.width = 650,
    this.height = 450,
  });

  final double latMin;
  final double latMax;
  final double lonMin;
  final double lonMax;
  final int width;
  final int height;

  factory MapBounds.fromJson(Map<String, dynamic> json) {
    return MapBounds(
      latMin: ((json['latMin'] ?? json['lat_min']) as num).toDouble(),
      latMax: ((json['latMax'] ?? json['lat_max']) as num).toDouble(),
      lonMin: ((json['lonMin'] ?? json['lon_min']) as num).toDouble(),
      lonMax: ((json['lonMax'] ?? json['lon_max']) as num).toDouble(),
      width: ((json['width'] ?? 650) as num).toInt(),
      height: ((json['height'] ?? 450) as num).toInt(),
    );
  }

  factory MapBounds.fromStops(List<Stop> stops) {
    const pad = 0.22;
    const minLatSpan = 0.004;
    const minLonSpan = 0.006;
    final lats = stops.map((stop) => stop.lat);
    final lons = stops.map((stop) => stop.lon);
    final latMin = lats.reduce((a, b) => a < b ? a : b);
    final latMax = lats.reduce((a, b) => a > b ? a : b);
    final lonMin = lons.reduce((a, b) => a < b ? a : b);
    final lonMax = lons.reduce((a, b) => a > b ? a : b);
    final latPad = _max((latMax - latMin) * pad, minLatSpan / 2);
    final lonPad = _max((lonMax - lonMin) * pad, minLonSpan / 2);
    return MapBounds(
      latMin: latMin - latPad,
      latMax: latMax + latPad,
      lonMin: lonMin - lonPad,
      lonMax: lonMax + lonPad,
    );
  }
}

double _max(double a, double b) => a > b ? a : b;

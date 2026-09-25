import 'guide.dart';

class HistoryEvent {
  const HistoryEvent({required this.year, required this.text});

  final String year;
  final String text;

  factory HistoryEvent.fromJson(Map<String, dynamic> json) {
    return HistoryEvent(
      year: '${json['year'] ?? ''}',
      text: json['text'] as String? ?? '',
    );
  }
}

class CityHistory {
  const CityHistory({
    this.founded = '',
    this.summary = '',
    this.events = const [],
  });

  final String founded;
  final String summary;
  final List<HistoryEvent> events;

  bool get isEmpty =>
      founded.trim().isEmpty && summary.trim().isEmpty && events.isEmpty;

  factory CityHistory.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const CityHistory();
    }
    return CityHistory(
      founded: json['founded'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      events: (json['events'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(HistoryEvent.fromJson)
          .toList(),
    );
  }
}

class CityPresent {
  const CityPresent({
    this.summary = '',
    this.population = '',
    this.economy = '',
  });

  final String summary;
  final String population;
  final String economy;

  bool get isEmpty =>
      summary.trim().isEmpty &&
      population.trim().isEmpty &&
      economy.trim().isEmpty;

  factory CityPresent.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const CityPresent();
    }
    return CityPresent(
      summary: json['summary'] as String? ?? '',
      population: json['population'] as String? ?? '',
      economy: json['economy'] as String? ?? '',
    );
  }
}

enum PlaceGroup { guide, food, sight, nature }

class CityPlace {
  const CityPlace({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.kind,
    this.summary = '',
  });

  final String id;
  final String name;
  final double lat;
  final double lon;
  final String kind;
  final String summary;

  PlaceGroup get group {
    switch (kind) {
      case 'coffee':
      case 'pastry':
      case 'restaurant':
        return PlaceGroup.food;
      case 'park':
      case 'viewpoint':
        return PlaceGroup.nature;
      case 'guide':
        return PlaceGroup.guide;
      default:
        return PlaceGroup.sight;
    }
  }

  factory CityPlace.fromJson(Map<String, dynamic> json) {
    return CityPlace(
      id: json['id'] as String,
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      kind: json['kind'] as String? ?? 'sight',
      summary: json['summary'] as String? ?? '',
    );
  }
}

class CityGuides {
  const CityGuides({this.short, this.long});

  final String? short;
  final String? long;

  factory CityGuides.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const CityGuides();
    }
    return CityGuides(
      short: json['short'] as String?,
      long: json['long'] as String?,
    );
  }
}

class CitySummary {
  const CitySummary({
    required this.id,
    required this.title,
    this.subtitle,
    required this.city,
    this.region,
    this.aliases = const [],
    required this.center,
    this.guides = const CityGuides(),
    this.contentVersion = 1,
    this.reviewedAt,
    this.sourceUrls = const [],
  });

  final String id;
  final String title;
  final String? subtitle;
  final String city;
  final String? region;
  final List<String> aliases;
  final LatLon center;
  final CityGuides guides;
  final int contentVersion;
  final String? reviewedAt;
  final List<String> sourceUrls;

  factory CitySummary.fromJson(Map<String, dynamic> json) {
    return CitySummary(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      city: json['city'] as String? ?? json['title'] as String,
      region: json['region'] as String?,
      aliases: (json['aliases'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
      center: LatLon.fromJson(json['center'] as Map<String, dynamic>),
      guides: CityGuides.fromJson(json['guides'] as Map<String, dynamic>?),
      contentVersion:
          (json['contentVersion'] ?? json['content_version'] ?? 1) as int,
      reviewedAt: json['reviewedAt'] as String?,
      sourceUrls: (json['sourceUrls'] as List<dynamic>? ?? [])
          .whereType<String>()
          .toList(),
    );
  }
}

class City extends CitySummary {
  const City({
    required super.id,
    required super.title,
    super.subtitle,
    required super.city,
    super.region,
    super.aliases,
    required super.center,
    super.guides,
    super.contentVersion,
    super.reviewedAt,
    super.sourceUrls,
    this.history = const CityHistory(),
    this.present = const CityPresent(),
    this.sights = const [],
    this.nature = const [],
    this.culture = const [],
    this.leisure = const [],
  });

  final CityHistory history;
  final CityPresent present;
  final List<CityPlace> sights;
  final List<CityPlace> nature;
  final List<CityPlace> culture;
  final List<CityPlace> leisure;

  List<CityPlace> get mapPlaces {
    final pins = <CityPlace>[
      ...sights,
      ...nature,
      ...culture,
      ...leisure,
    ];
    if (guides.short != null || guides.long != null) {
      pins.insert(
        0,
        CityPlace(
          id: 'guide-$id',
          name: 'Аудиогид',
          lat: center.lat,
          lon: center.lon,
          kind: 'guide',
          summary: [
            if (guides.short != null) 'короткий',
            if (guides.long != null) 'длинный',
          ].join(' · '),
        ),
      );
    }
    return pins;
  }

  factory City.fromJson(Map<String, dynamic> json) {
    List<CityPlace> places(String key) {
      return (json[key] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(CityPlace.fromJson)
          .toList();
    }

    final summary = CitySummary.fromJson(json);
    return City(
      id: summary.id,
      title: summary.title,
      subtitle: summary.subtitle,
      city: summary.city,
      region: summary.region,
      aliases: summary.aliases,
      center: summary.center,
      guides: summary.guides,
      contentVersion: summary.contentVersion,
      reviewedAt: summary.reviewedAt,
      sourceUrls: summary.sourceUrls,
      history: CityHistory.fromJson(json['history'] as Map<String, dynamic>?),
      present: CityPresent.fromJson(json['present'] as Map<String, dynamic>?),
      sights: places('sights'),
      nature: places('nature'),
      culture: places('culture'),
      leisure: places('leisure'),
    );
  }
}

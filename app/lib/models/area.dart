import 'guide.dart';
import 'city.dart';

enum AreaType { country, region }

class AreaSummary {
  const AreaSummary({
    required this.id,
    required this.type,
    required this.title,
    this.subtitle,
    this.summary = '',
    this.parentId,
    this.countryCode,
    this.navigationMode = 'flat',
    required this.center,
    this.aliases = const [],
    this.childAreaIds = const [],
    this.cityIds = const [],
    this.placeIds = const [],
    this.routeIds = const [],
    this.overviewGuideId,
    this.contentVersion = 1,
    this.history = const CityHistory(),
    this.present = const CityPresent(),
    this.sights = const [],
    this.nature = const [],
    this.culture = const [],
    this.leisure = const [],
    this.reviewedAt,
    this.sourceUrls = const [],
  });

  final String id;
  final AreaType type;
  final String title;
  final String? subtitle;
  final String summary;
  final String? parentId;
  final String? countryCode;
  final String navigationMode;
  final LatLon center;
  final List<String> aliases;
  final List<String> childAreaIds;
  final List<String> cityIds;
  final List<String> placeIds;
  final List<String> routeIds;
  final String? overviewGuideId;
  final int contentVersion;
  final CityHistory history;
  final CityPresent present;
  final List<CityPlace> sights;
  final List<CityPlace> nature;
  final List<CityPlace> culture;
  final List<CityPlace> leisure;
  final String? reviewedAt;
  final List<String> sourceUrls;

  bool get isCountry => type == AreaType.country;

  factory AreaSummary.fromJson(Map<String, dynamic> json) {
    List<String> ids(String key) =>
        (json[key] as List<dynamic>? ?? []).whereType<String>().toList();
    List<CityPlace> places(String key) => (json[key] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(CityPlace.fromJson)
        .toList();

    return AreaSummary(
      id: json['id'] as String,
      type: json['type'] == 'region' ? AreaType.region : AreaType.country,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      summary: json['summary'] as String? ?? '',
      parentId: json['parentId'] as String?,
      countryCode: json['countryCode'] as String?,
      navigationMode: json['navigationMode'] as String? ?? 'flat',
      center: LatLon.fromJson(json['center'] as Map<String, dynamic>),
      aliases: ids('aliases'),
      childAreaIds: ids('childAreaIds'),
      cityIds: ids('cityIds'),
      placeIds: ids('placeIds'),
      routeIds: ids('routeIds'),
      overviewGuideId: json['overviewGuideId'] as String?,
      contentVersion:
          (json['contentVersion'] ?? json['content_version'] ?? 1) as int,
      history: CityHistory.fromJson(json['history'] as Map<String, dynamic>?),
      present: CityPresent.fromJson(json['present'] as Map<String, dynamic>?),
      sights: places('sights'),
      nature: places('nature'),
      culture: places('culture'),
      leisure: places('leisure'),
      reviewedAt: json['reviewedAt'] as String?,
      sourceUrls: ids('sourceUrls'),
    );
  }
}

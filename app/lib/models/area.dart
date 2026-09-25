import 'guide.dart';

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

  bool get isCountry => type == AreaType.country;

  factory AreaSummary.fromJson(Map<String, dynamic> json) {
    List<String> ids(String key) =>
        (json[key] as List<dynamic>? ?? []).whereType<String>().toList();

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
    );
  }
}

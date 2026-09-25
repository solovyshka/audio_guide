import 'dart:convert';

import 'package:flutter/services.dart';

import '../api/client.dart';
import '../models/area.dart';
import '../models/city.dart';
import '../models/guide.dart';
import '../net/api_door.dart';
import 'content_pack_store_io.dart'
    if (dart.library.html) 'content_pack_store_web.dart';

class ContentPack {
  ContentPack._();

  static final ContentPack instance = ContentPack._();

  List<City> _cities = [];
  List<Guide> _guides = [];
  List<AreaSummary> _areas = [];

  List<CitySummary> get cities => _cities;

  List<Guide> get guides => _guides;

  List<AreaSummary> get areas => _areas;

  List<AreaSummary> get countries =>
      _areas.where((item) => item.isCountry).toList();

  Future<void> load() async {
    final saved = await ContentPackStore.read();
    final bundled = jsonDecode(
      await rootBundle.loadString('assets/content/pack.json'),
    );
    if (saved == null) {
      _apply(bundled);
      return;
    }
    final stored = jsonDecode(saved);
    if (stored is Map<String, dynamic> && bundled is Map<String, dynamic>) {
      if (stored['areas'] is! List || (stored['areas'] as List).isEmpty) {
        stored['areas'] = bundled['areas'];
      }
    }
    _apply(stored);
  }

  City? city(String id) {
    for (final item in _cities) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  Guide? guide(String id) {
    for (final item in _guides) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  AreaSummary? area(String id) {
    for (final item in _areas) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  CitySummary? citySummary(String id) => city(id);

  List<CitySummary> search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) {
      return cities;
    }
    return _cities.where((item) {
      final hay = [
        item.id,
        item.title,
        item.city,
        item.subtitle ?? '',
        item.region ?? '',
        ...item.aliases,
      ].join(' ').toLowerCase();
      return hay.contains(needle);
    }).toList();
  }

  Future<void> refresh(GuideApi api) async {
    final areas = <Map<String, dynamic>>[];
    try {
      for (final item in await api.listAreas()) {
        areas.add(await api.getAreaJson(item.id));
      }
    } catch (_) {
      areas.addAll(
        _areas.map((item) => <String, dynamic>{
              'id': item.id,
              'type': item.type.name,
              'title': item.title,
              'subtitle': item.subtitle,
              'summary': item.summary,
              'parentId': item.parentId,
              'countryCode': item.countryCode,
              'navigationMode': item.navigationMode,
              'center': {'lat': item.center.lat, 'lon': item.center.lon},
              'aliases': item.aliases,
              'childAreaIds': item.childAreaIds,
              'cityIds': item.cityIds,
              'placeIds': item.placeIds,
              'routeIds': item.routeIds,
              'overviewGuideId': item.overviewGuideId,
              'contentVersion': item.contentVersion,
            }),
      );
    }
    final listed = await api.listCities();
    final cities = <Map<String, dynamic>>[];
    for (final item in listed) {
      cities.add(await api.getCityJson(item.id));
    }
    final guides = <Map<String, dynamic>>[];
    final seen = <String>{};
    Future<void> addGuide(String? id) async {
      if (id == null || id.isEmpty || !seen.add(id)) {
        return;
      }
      guides.add(await api.getGuideJson(id));
    }

    for (final city in cities) {
      final links = city['guides'];
      if (links is Map) {
        await addGuide(links['short'] as String?);
        await addGuide(links['long'] as String?);
      }
    }
    try {
      for (final item in await api.listGuides()) {
        await addGuide(item.id);
      }
    } catch (_) {}
    final text = jsonEncode({
      'version': 2,
      'areas': areas,
      'cities': cities,
      'guides': guides,
    });
    await ContentPackStore.write(text);
    _apply(jsonDecode(text));
  }

  void _apply(Object? raw) {
    final pack = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    _areas = (pack['areas'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(AreaSummary.fromJson)
        .toList();
    _cities = (pack['cities'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(City.fromJson)
        .toList();
    _guides = (pack['guides'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((item) =>
            Guide.fromJson(_withAudio(Map<String, dynamic>.from(item))))
        .toList();
  }
}

Map<String, dynamic> _withAudio(Map<String, dynamic> guide) {
  final id = guide['id'];
  void fix(Object? node) {
    if (node is! Map) {
      return;
    }
    final path = node['audioPath'] ?? node['audio_path'];
    final current = node['audioUrl'] ?? node['audio_url'];
    if (current is String && current.isNotEmpty) {
      node['audioUrl'] = ApiDoor.pin(current);
    } else if (id is String && path is String && path.isNotEmpty) {
      final relative = path.replaceFirst(RegExp(r'^/'), '');
      node['audioUrl'] = '${ApiDoor.current}/media/guides/$id/$relative';
    }
  }

  fix(guide['intro']);
  final stops = guide['stops'];
  if (stops is List) {
    for (final stop in stops) {
      fix(stop);
    }
  }
  final mapUrl = guide['mapUrl'] ?? guide['map_url'];
  if (mapUrl is String && mapUrl.isNotEmpty) {
    guide['mapUrl'] = ApiDoor.pin(mapUrl);
  }
  return guide;
}

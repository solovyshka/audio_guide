import 'dart:convert';

import 'package:flutter/services.dart';

import '../api/client.dart';
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

  List<CitySummary> get cities => _cities;

  List<Guide> get guides => _guides;

  Future<void> load() async {
    final saved = await ContentPackStore.read();
    final raw = saved ?? await rootBundle.loadString('assets/content/pack.json');
    _apply(jsonDecode(raw));
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
    final text = jsonEncode({'cities': cities, 'guides': guides});
    await ContentPackStore.write(text);
    _apply(jsonDecode(text));
  }

  void _apply(Object? raw) {
    final pack = raw is Map<String, dynamic> ? raw : <String, dynamic>{};
    _cities = (pack['cities'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(City.fromJson)
        .toList();
    _guides = (pack['guides'] as List<dynamic>? ?? [])
        .whereType<Map>()
        .map((item) => Guide.fromJson(_withAudio(Map<String, dynamic>.from(item))))
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

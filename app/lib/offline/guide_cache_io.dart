import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../api/client.dart';
import '../models/guide.dart';
import 'download_progress.dart';

class GuideCache extends ChangeNotifier {
  GuideCache._();

  static final GuideCache instance = GuideCache._();

  final Map<String, int> _versions = {};
  final Map<String, DownloadProgress> _progress = {};
  final Map<String, Future<void>> _jobs = {};

  Future<void> init() async {
    final root = await _root();
    if (!await root.exists()) {
      await root.create(recursive: true);
      return;
    }
    await for (final entity in root.list()) {
      if (entity is! Directory) {
        continue;
      }
      if (entity.path.endsWith('.download')) {
        await entity.delete(recursive: true);
        continue;
      }
      final id = _idFromDir(entity);
      final version = await _readVersion(entity);
      if (id != null && version != null) {
        _versions[id] = version;
      }
    }
    notifyListeners();
  }

  bool isDownloaded(String id) => _versions.containsKey(id);

  int? localVersion(String id) => _versions[id];

  bool isDownloading(String id) => _jobs.containsKey(id);

  DownloadProgress? progressOf(String id) => _progress[id];

  Future<List<GuideSummary>> localCatalog() async {
    final root = await _root();
    if (!await root.exists()) {
      return [];
    }
    final guides = <GuideSummary>[];
    await for (final entity in root.list()) {
      if (entity is! Directory || entity.path.endsWith('.download')) {
        continue;
      }
      final file = File('${entity.path}/guide.json');
      if (!await file.exists()) {
        continue;
      }
      try {
        guides.add(
          Guide.fromJson(
            jsonDecode(await file.readAsString()) as Map<String, dynamic>,
          ),
        );
      } catch (_) {
        continue;
      }
    }
    return guides;
  }

  Future<Guide?> loadLocal(String id) async {
    final safe = _safeId(id);
    final dir = Directory('${(await _root()).path}/$safe');
    final file = File('${dir.path}/guide.json');
    if (!await file.exists()) {
      return null;
    }
    final guide = Guide.fromJson(
      jsonDecode(await file.readAsString()) as Map<String, dynamic>,
    );
    return withLocalAudio(guide);
  }

  Future<Guide> withLocalAudio(Guide guide) async {
    final safe = _safeId(guide.id);
    final dir = Directory('${(await _root()).path}/$safe');
    final manifestFile = File('${dir.path}/manifest.json');
    if (!await manifestFile.exists()) {
      return guide;
    }
    final manifest =
        jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
    final files = (manifest['files'] as Map<String, dynamic>?) ?? {};
    final introPath = await _existingPath(dir, files['intro'] as String?);
    final stops = <Stop>[];
    for (final stop in guide.stops) {
      final local = await _existingPath(dir, files[stop.id] as String?);
      stops.add(
        Stop(
          id: stop.id,
          name: stop.name,
          lat: stop.lat,
          lon: stop.lon,
          order: stop.order,
          category: stop.category,
          title: stop.title,
          text: stop.text,
          audioUrl: local ?? stop.audioUrl,
          durationSec: stop.durationSec,
        ),
      );
    }
    return Guide(
      id: guide.id,
      title: guide.title,
      subtitle: guide.subtitle,
      city: guide.city,
      stopsCount: guide.stopsCount,
      durationSec: guide.durationSec,
      contentVersion: guide.contentVersion,
      center: guide.center,
      intro: Track(
        title: guide.intro.title,
        text: guide.intro.text,
        audioUrl: introPath ?? guide.intro.audioUrl,
        durationSec: guide.intro.durationSec,
      ),
      stops: stops,
    );
  }

  Future<void> download(GuideApi api, String id) {
    final safe = _safeId(id);
    return _jobs.putIfAbsent(safe, () async {
      try {
        await _download(api, safe);
      } finally {
        _jobs.remove(safe);
        _progress.remove(safe);
        notifyListeners();
      }
    });
  }

  Future<void> delete(String id) async {
    final safe = _safeId(id);
    final dir = Directory('${(await _root()).path}/$safe');
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    _versions.remove(safe);
    notifyListeners();
  }

  Future<void> _download(GuideApi api, String id) async {
    final root = await _root();
    await root.create(recursive: true);
    final staging = Directory('${root.path}/$id.download');
    if (await staging.exists()) {
      await staging.delete(recursive: true);
    }
    await staging.create(recursive: true);

    final payload = await api.getGuideJson(id);
    final guide = Guide.fromJson(payload);
    await File('${staging.path}/guide.json').writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );

    final files = <String, String>{};
    final tracks = <({String key, String url})>[];
    final introUrl = guide.intro.audioUrl;
    if (introUrl != null && introUrl.isNotEmpty) {
      tracks.add((key: 'intro', url: introUrl));
    }
    for (final stop in guide.stops) {
      final url = stop.audioUrl;
      if (url != null && url.isNotEmpty) {
        tracks.add((key: stop.id, url: url));
      }
    }

    final client = http.Client();
    try {
      for (var i = 0; i < tracks.length; i++) {
        final track = tracks[i];
        _progress[id] = DownloadProgress(
          completed: i,
          total: tracks.length,
          label: track.key == 'intro' ? 'Вступление' : track.key,
        );
        notifyListeners();
        final relative = _relativeAudioPath(id, track.url);
        files[track.key] = relative;
        await _fetchFile(client, track.url, File('${staging.path}/$relative'));
      }
    } finally {
      client.close();
    }

    await File('${staging.path}/manifest.json').writeAsString(
      jsonEncode({
        'id': id,
        'contentVersion': guide.contentVersion,
        'files': files,
      }),
    );

    final dest = Directory('${root.path}/$id');
    if (await dest.exists()) {
      await dest.delete(recursive: true);
    }
    await staging.rename(dest.path);
    _versions[id] = guide.contentVersion;
    notifyListeners();
  }

  Future<Directory> _root() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/guides');
  }

  Future<String?> _existingPath(Directory dir, String? relative) async {
    if (relative == null || relative.contains('..')) {
      return null;
    }
    final file = File('${dir.path}/$relative');
    if (await file.exists()) {
      return file.path;
    }
    return null;
  }

  Future<int?> _readVersion(Directory dir) async {
    final manifest = File('${dir.path}/manifest.json');
    if (await manifest.exists()) {
      try {
        final data =
            jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
        return (data['contentVersion'] ?? data['content_version']) as int?;
      } catch (_) {}
    }
    final guideFile = File('${dir.path}/guide.json');
    if (await guideFile.exists()) {
      try {
        final data =
            jsonDecode(await guideFile.readAsString()) as Map<String, dynamic>;
        return (data['contentVersion'] ?? data['content_version'] ?? 1) as int;
      } catch (_) {}
    }
    return null;
  }

  String? _idFromDir(Directory dir) {
    final name = dir.uri.pathSegments.where((part) => part.isNotEmpty).last;
    return name.isEmpty ? null : name;
  }
}

String _safeId(String id) {
  final safe = id.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
  if (safe.isEmpty) {
    throw ArgumentError('Некорректный идентификатор гида');
  }
  return safe;
}

String _relativeAudioPath(String guideId, String url) {
  final uri = Uri.parse(url);
  final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
  final idx = segments.indexOf(guideId);
  if (idx >= 0 && idx < segments.length - 1) {
    final relative = segments.sublist(idx + 1).join('/');
    if (relative.contains('..')) {
      throw Exception('Некорректный путь аудио');
    }
    return relative;
  }
  final name = segments.isEmpty ? 'track.bin' : segments.last;
  return 'audio/$name';
}

Future<void> _fetchFile(http.Client client, String url, File dest) async {
  await dest.parent.create(recursive: true);
  final tmp = File('${dest.path}.part');
  final request = http.Request('GET', Uri.parse(url));
  final response = await client.send(request);
  if (response.statusCode != 200) {
    throw Exception('Не удалось скачать аудио (${response.statusCode})');
  }
  final sink = tmp.openWrite();
  try {
    await sink.addStream(response.stream);
  } finally {
    await sink.close();
  }
  if (await dest.exists()) {
    await dest.delete();
  }
  await tmp.rename(dest.path);
}

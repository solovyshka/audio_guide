import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

class _Probe {
  const _Probe(this.base, this.elapsed);

  final String base;
  final Duration elapsed;
}

/// Picks the door whose small health packet comes back, and fastest.
class ApiDoor {
  static String current = _normalize(apiBase);

  static List<String> get doors {
    final seen = <String>{};
    final list = <String>[];
    for (final raw in [apiBase, ...apiDoors]) {
      final base = _normalize(raw);
      if (base.isEmpty || !seen.add(base)) {
        continue;
      }
      list.add(base);
    }
    return list;
  }

  static Future<String> select() async {
    final probes = await Future.wait(doors.map(_probe));
    final ok = [for (final item in probes) if (item != null) item]
      ..sort((a, b) => a.elapsed.compareTo(b.elapsed));
    if (ok.isNotEmpty) {
      current = ok.first.base;
    }
    return current;
  }

  static String shortLabel(String door) {
    final host = Uri.parse(_normalize(door)).host;
    if (host.contains('vladislavsolovei.ru')) {
      return 'RU';
    }
    if (host.contains('solovyshka.com')) {
      return 'FR';
    }
    return host;
  }

  static String updateUrl(String door) => '${_normalize(door)}/app/update.bin';

  /// Point a media or APK URL at the door we already chose.
  static String pin(String url, {String? door}) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      return url;
    }
    final roots = [...doors]..sort((a, b) => b.length.compareTo(a.length));
    for (final door in roots) {
      final root = Uri.parse(door);
      if (uri.host != root.host || uri.scheme != root.scheme) {
        continue;
      }
      final prefix = root.path == '/' ? '' : root.path;
      if (prefix.isNotEmpty &&
          uri.path != prefix &&
          !uri.path.startsWith('$prefix/')) {
        continue;
      }
      final rest = prefix.isEmpty ? uri.path : uri.path.substring(prefix.length);
      final pinned = '${_normalize(door)}$rest';
      if (!uri.hasQuery) {
        return pinned;
      }
      return '$pinned?${uri.query}';
    }
    return url;
  }

  static void pinTree(dynamic node) {
    if (node is Map) {
      for (final entry in node.entries.toList()) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is String && _urlKeys.contains(key)) {
          node[key] = pin(value);
        } else {
          pinTree(value);
        }
      }
    } else if (node is List) {
      for (final item in node) {
        pinTree(item);
      }
    }
  }
}

const _urlKeys = {
  'audioUrl',
  'audio_url',
  'mapUrl',
  'map_url',
  'apkUrl',
  'apk_url',
};

String _normalize(String raw) => raw.trim().replaceAll(RegExp(r'/+$'), '');

Future<_Probe?> _probe(String base) async {
  final client = http.Client();
  final watch = Stopwatch()..start();
  try {
    final response = await client.get(
      Uri.parse('$base/health'),
      headers: const {
        'Cache-Control': 'no-cache',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 4));
    watch.stop();
    if (response.statusCode != 200 || response.bodyBytes.length > 2048) {
      return null;
    }
    final body = jsonDecode(utf8.decode(response.bodyBytes));
    if (body is! Map || body['status'] != 'ok') {
      return null;
    }
    return _Probe(base, watch.elapsed);
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
}

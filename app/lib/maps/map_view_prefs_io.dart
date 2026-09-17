import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'map_view_mode.dart';

class MapViewPrefs {
  static Future<File> _file() async {
    final docs = await getApplicationDocumentsDirectory();
    return File('${docs.path}/map_view_mode.txt');
  }

  static Future<MapViewMode?> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) {
        return null;
      }
      final raw = (await file.readAsString()).trim();
      for (final mode in MapViewMode.values) {
        if (mode.name == raw) {
          return mode;
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<void> save(MapViewMode mode) async {
    try {
      final file = await _file();
      await file.writeAsString(mode.name);
    } catch (_) {}
  }
}

import 'map_view_mode.dart';

class MapViewPrefs {
  static MapViewMode? _memory;

  static Future<MapViewMode?> load() async => _memory;

  static Future<void> save(MapViewMode mode) async {
    _memory = mode;
  }
}

import 'package:flutter/material.dart';
import 'package:yandex_maps_mapkit_lite/mapkit.dart' hide Icon;
import 'package:yandex_maps_mapkit_lite/mapkit_factory.dart';
import 'package:yandex_maps_mapkit_lite/yandex_map.dart';

import '../models/guide.dart';

class GuideYandexMap extends StatefulWidget {
  const GuideYandexMap({
    super.key,
    required this.guide,
    required this.onStopTap,
  });

  final Guide guide;
  final ValueChanged<int> onStopTap;

  @override
  State<GuideYandexMap> createState() => _GuideYandexMapState();
}

class _GuideYandexMapState extends State<GuideYandexMap>
    with WidgetsBindingObserver {
  MapWindow? _mapWindow;
  final List<MapObjectTapListener> _tapListeners = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(GuideYandexMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.guide.id != widget.guide.id) {
      _drawStops();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      mapkit.onStart();
    } else if (state == AppLifecycleState.paused) {
      mapkit.onStop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onMapCreated(MapWindow mapWindow) {
    _mapWindow = mapWindow;
    _drawStops();
  }

  void _drawStops() {
    final mapWindow = _mapWindow;
    if (mapWindow == null) {
      return;
    }
    mapWindow.map.mapObjects.clear();
    _tapListeners.clear();
    for (final stop in widget.guide.stops) {
      final listener = _StopTapListener((_) {
        widget.onStopTap(stop.order);
      });
      _tapListeners.add(listener);
      final placemark = mapWindow.map.mapObjects.addPlacemark()
        ..geometry = Point(latitude: stop.lat, longitude: stop.lon)
        ..setText('${stop.order}. ${stop.name}');
      placemark.addTapListener(listener);
    }
    mapWindow.map.move(
      CameraPosition(
        Point(
          latitude: widget.guide.center.lat,
          longitude: widget.guide.center.lon,
        ),
        zoom: 14,
        azimuth: 0,
        tilt: 0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return YandexMap(onMapCreated: _onMapCreated);
  }
}

final class _StopTapListener implements MapObjectTapListener {
  _StopTapListener(this.onTap);

  final void Function(MapObject object) onTap;

  @override
  bool onMapObjectTap(MapObject mapObject, Point point) {
    onTap(mapObject);
    return true;
  }
}

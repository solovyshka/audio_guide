import 'dart:math' as math;

import 'package:flutter/material.dart' hide TextStyle;
import 'package:yandex_maps_mapkit_lite/image.dart' as mk_image;
import 'package:yandex_maps_mapkit_lite/mapkit.dart' hide Icon;
import 'package:yandex_maps_mapkit_lite/mapkit_factory.dart';
import 'package:yandex_maps_mapkit_lite/yandex_map.dart';

import '../models/guide.dart';
import 'marker_icon.dart';
import 'user_location.dart';

class GuideYandexMap extends StatefulWidget {
  const GuideYandexMap({
    super.key,
    required this.guide,
    required this.currentIndex,
    required this.onStopTap,
    this.user,
  });

  final Guide guide;
  final int currentIndex;
  final ValueChanged<int> onStopTap;
  final UserFix? user;

  @override
  State<GuideYandexMap> createState() => _GuideYandexMapState();
}

class _GuideYandexMapState extends State<GuideYandexMap>
    with WidgetsBindingObserver {
  MapWindow? _mapWindow;
  final List<MapObjectTapListener> _tapListeners = [];
  bool _didMoveCamera = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(GuideYandexMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.guide.id != widget.guide.id) {
      _didMoveCamera = false;
      _drawStops(moveCamera: true);
      return;
    }
    if (oldWidget.currentIndex != widget.currentIndex) {
      _drawStops();
      return;
    }
    if (oldWidget.user?.lat != widget.user?.lat ||
        oldWidget.user?.lon != widget.user?.lon) {
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
    _drawStops(moveCamera: true);
  }

  double get _dpr =>
      View.of(context).devicePixelRatio;

  void _drawStops({bool moveCamera = false}) {
    final mapWindow = _mapWindow;
    if (mapWindow == null) {
      return;
    }
    mapWindow.map.mapObjects.clear();
    _tapListeners.clear();
    for (final stop in widget.guide.stops) {
      final active = stop.order == widget.currentIndex;
      final listener = _StopTapListener((_) {
        widget.onStopTap(stop.order);
      });
      _tapListeners.add(listener);
      final placemark = mapWindow.map.mapObjects.addPlacemark()
        ..geometry = Point(latitude: stop.lat, longitude: stop.lon)
        ..zIndex = active ? 100 : stop.order.toDouble();
      placemark.setIconWithStyle(
        mk_image.ImageProvider(
          () => paintStopMarker(
            number: stop.order,
            active: active,
            devicePixelRatio: _dpr,
          ),
          id: 'stop-${stop.order}-${active ? 'on' : 'off'}',
        ),
        IconStyle(anchor: const math.Point(0.5, 0.5)),
      );
      if (active) {
        placemark.setTextWithStyle(
          const TextStyle(
            size: 12,
            color: Color(0xFF1F4B3A),
            outlineWidth: 2.4,
            outlineColor: Color(0xFFFFFFFF),
            placement: TextStylePlacement.Bottom,
            offset: 6,
            offsetFromIcon: true,
            textOptional: true,
          ),
          text: stop.name,
        );
      } else {
        placemark.setText('');
      }
      placemark.addTapListener(listener);
    }
    final user = widget.user;
    if (user != null) {
      final me = mapWindow.map.mapObjects.addPlacemark()
        ..geometry = Point(latitude: user.lat, longitude: user.lon)
        ..zIndex = 200;
      me.setIconWithStyle(
        mk_image.ImageProvider(
          () => paintUserMarker(devicePixelRatio: _dpr),
          id: 'user-dot',
        ),
        IconStyle(anchor: const math.Point(0.5, 0.5)),
      );
    }
    if (moveCamera || !_didMoveCamera) {
      _didMoveCamera = true;
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

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../models/city.dart';
import 'available.dart';
import 'city_yandex_view.dart';
import 'location_hint.dart';
import 'map_controls.dart';
import 'map_view_mode.dart';
import 'map_view_prefs.dart';
import 'map_view_switcher.dart';
import 'stop_chip.dart';
import 'user_dot.dart';
import 'user_location.dart';

class CityMap extends StatefulWidget {
  const CityMap({
    super.key,
    required this.city,
    this.selectedId,
    required this.onPlaceTap,
  });

  final City city;
  final String? selectedId;
  final ValueChanged<CityPlace> onPlaceTap;

  @override
  State<CityMap> createState() => _CityMapState();
}

class _CityMapState extends State<CityMap> {
  late MapViewMode _mode = _fallback(null);

  bool get _hasYandex => yandexMapsSupported && mapkitApiKey.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _restore();
    UserLocation.instance.attach();
  }

  @override
  void didUpdateWidget(CityMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.city.id != widget.city.id) {
      setState(() => _mode = _fallback(_mode));
    }
  }

  @override
  void dispose() {
    UserLocation.instance.detach();
    super.dispose();
  }

  Future<void> _restore() async {
    final saved = await MapViewPrefs.load();
    if (!mounted) {
      return;
    }
    setState(() => _mode = _fallback(saved));
  }

  MapViewMode _fallback(MapViewMode? wanted) {
    if (wanted == MapViewMode.yandex && _hasYandex) {
      return MapViewMode.yandex;
    }
    if (wanted == null && _hasYandex) {
      return MapViewMode.yandex;
    }
    return MapViewMode.osm;
  }

  Future<void> _select(MapViewMode mode) async {
    setState(() => _mode = mode);
    await MapViewPrefs.save(mode);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UserLocation.instance,
      builder: (context, _) {
        final user = UserLocation.instance.fix;
        return Stack(
          children: [
            Positioned.fill(child: _body(user)),
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Align(
                alignment: Alignment.topCenter,
                child: MapViewSwitcher(
                  mode: _mode,
                  hasYandex: _hasYandex,
                  onChanged: _select,
                ),
              ),
            ),
            const Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: LocationHint(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _body(UserFix? user) {
    switch (_mode) {
      case MapViewMode.yandex:
        return CityYandexMap(
          city: widget.city,
          selectedId: widget.selectedId,
          onPlaceTap: widget.onPlaceTap,
          user: user,
        );
      case MapViewMode.osm:
        return _CityOsmMap(
          city: widget.city,
          selectedId: widget.selectedId,
          onPlaceTap: widget.onPlaceTap,
          user: user,
        );
    }
  }
}

class _CityOsmMap extends StatefulWidget {
  const _CityOsmMap({
    required this.city,
    this.selectedId,
    required this.onPlaceTap,
    this.user,
  });

  final City city;
  final String? selectedId;
  final ValueChanged<CityPlace> onPlaceTap;
  final UserFix? user;

  @override
  State<_CityOsmMap> createState() => _CityOsmMapState();
}

class _CityOsmMapState extends State<_CityOsmMap> {
  final _controller = MapController();
  bool _didCenter = false;
  bool _mapReady = false;

  @override
  void didUpdateWidget(_CityOsmMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.city.id != widget.city.id) {
      _didCenter = false;
      _centerIfNeeded();
      return;
    }
    if (oldWidget.selectedId != widget.selectedId &&
        widget.selectedId != null) {
      _centerSelected();
    }
  }

  void _centerSelected() {
    if (!_mapReady) {
      return;
    }
    CityPlace? selected;
    for (final place in widget.city.mapPlaces) {
      if (place.id == widget.selectedId) {
        selected = place;
        break;
      }
    }
    if (selected == null) {
      return;
    }
    final point = LatLng(selected.lat, selected.lon);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _controller.move(point, _controller.camera.zoom.clamp(16, 19));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _centerIfNeeded() {
    if (_didCenter || !_mapReady) {
      return;
    }
    _didCenter = true;
    final user = widget.user;
    final points = <LatLng>[
      if (user != null) LatLng(user.lat, user.lon),
      for (final place in widget.city.mapPlaces) LatLng(place.lat, place.lon),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || points.isEmpty) {
        return;
      }
      if (points.length == 1) {
        _controller.move(points.first, 15);
        return;
      }
      _controller.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.all(36),
          maxZoom: 16,
        ),
      );
    });
  }

  void _zoom(double delta) {
    if (!_mapReady) {
      return;
    }
    _controller.move(
      _controller.camera.center,
      (_controller.camera.zoom + delta).clamp(3, 19),
    );
  }

  Future<void> _locate() async {
    final user = await UserLocation.instance.refresh();
    if (!mounted || !_mapReady || user == null) {
      return;
    }
    _controller.move(
      LatLng(user.lat, user.lon),
      _controller.camera.zoom.clamp(15, 19),
    );
  }

  IconData _icon(PlaceGroup group) {
    switch (group) {
      case PlaceGroup.guide:
        return Icons.headset;
      case PlaceGroup.food:
        return Icons.restaurant;
      case PlaceGroup.nature:
        return Icons.park;
      case PlaceGroup.sight:
        return Icons.account_balance;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final places = widget.city.mapPlaces;
    return ColoredBox(
      color: const Color(0xFFE8E4DC),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: LatLng(
                widget.city.center.lat,
                widget.city.center.lon,
              ),
              initialZoom: 14,
              onMapReady: () {
                _mapReady = true;
                _centerIfNeeded();
              },
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.solovyshka.audio_guide',
              ),
              MarkerLayer(
                markers: [
                  for (final place in places)
                    Marker(
                      point: LatLng(place.lat, place.lon),
                      width: place.id == widget.selectedId ? 150 : 32,
                      height: place.id == widget.selectedId ? 66 : 32,
                      alignment: Alignment.center,
                      child: GestureDetector(
                        onTap: () => widget.onPlaceTap(place),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: place.id == widget.selectedId ? 42 : 30,
                              height: place.id == widget.selectedId ? 42 : 30,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: place.id == widget.selectedId
                                    ? activeFill
                                    : idleFill,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: place.id == widget.selectedId
                                      ? activeStroke
                                      : idleStroke,
                                  width: place.id == widget.selectedId ? 3 : 2,
                                ),
                                boxShadow: place.id == widget.selectedId
                                    ? const [
                                        BoxShadow(
                                          color: Color(0x551F4B3A),
                                          blurRadius: 8,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                _icon(place.group),
                                size: place.id == widget.selectedId ? 21 : 15,
                                color: place.id == widget.selectedId
                                    ? activeText
                                    : idleStroke,
                              ),
                            ),
                            if (place.id == widget.selectedId)
                              Container(
                                constraints:
                                    const BoxConstraints(maxWidth: 146),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xF2FFE59A),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  place.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF17392C),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (user != null)
                    Marker(
                      point: LatLng(user.lat, user.lon),
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      child: const UserDot(),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            right: 10,
            bottom: 48,
            child: MapControls(
              onZoomIn: () => _zoom(1),
              onZoomOut: () => _zoom(-1),
              onLocate: _locate,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/city.dart';
import 'location_hint.dart';
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
  final _controller = MapController();
  bool _didCenter = false;
  bool _mapReady = false;

  @override
  void initState() {
    super.initState();
    UserLocation.instance
      ..addListener(_onLocation)
      ..attach();
  }

  @override
  void didUpdateWidget(CityMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.city.id != widget.city.id) {
      _didCenter = false;
      _centerIfNeeded();
    }
  }

  @override
  void dispose() {
    UserLocation.instance
      ..removeListener(_onLocation)
      ..detach();
    _controller.dispose();
    super.dispose();
  }

  void _onLocation() {
    if (mounted) {
      setState(() {});
    }
  }

  void _centerIfNeeded() {
    if (_didCenter || !_mapReady) {
      return;
    }
    _didCenter = true;
    final user = UserLocation.instance.fix;
    final points = <LatLng>[
      if (user != null) LatLng(user.lat, user.lon),
      for (final place in widget.city.mapPlaces)
        LatLng(place.lat, place.lon),
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
    final user = UserLocation.instance.fix;
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
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      child: GestureDetector(
                        onTap: () => widget.onPlaceTap(place),
                        child: Container(
                          width: 28,
                          height: 28,
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
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            _icon(place.group),
                            size: 14,
                            color: place.id == widget.selectedId
                                ? activeText
                                : idleStroke,
                          ),
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
          if (user == null)
            const Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: LocationHint(),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/guide.dart';
import 'location_hint.dart';
import 'stop_chip.dart';
import 'user_dot.dart';
import 'user_location.dart';

const _nearbyMeters = 50000.0;

class NearbyMap extends StatefulWidget {
  const NearbyMap({
    super.key,
    required this.guides,
    required this.onGuideTap,
  });

  final List<GuideSummary> guides;
  final ValueChanged<GuideSummary> onGuideTap;

  @override
  State<NearbyMap> createState() => _NearbyMapState();
}

class _NearbyMapState extends State<NearbyMap> {
  final _controller = MapController();
  final _distance = const Distance();
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
  void didUpdateWidget(NearbyMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.guides.length != widget.guides.length) {
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
    if (!mounted) {
      return;
    }
    setState(() {});
    _centerIfNeeded();
  }

  List<({GuideSummary guide, double meters})> _scored(UserFix? user) {
    if (user == null) {
      return [];
    }
    final scored = [
      for (final guide in widget.guides)
        (
          guide: guide,
          meters: _distance.as(
            LengthUnit.Meter,
            LatLng(user.lat, user.lon),
            LatLng(guide.center.lat, guide.center.lon),
          ),
        ),
    ]..sort((a, b) => a.meters.compareTo(b.meters));
    final close = scored.where((item) => item.meters <= _nearbyMeters).toList();
    return close;
  }

  void _centerIfNeeded() {
    if (_didCenter || !_mapReady) {
      return;
    }
    final user = UserLocation.instance.fix;
    final nearby = _scored(user);
    if (user == null && nearby.isEmpty) {
      return;
    }
    _didCenter = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (user != null && nearby.isEmpty) {
        _controller.move(LatLng(user.lat, user.lon), 14);
        return;
      }
      final points = <LatLng>[
        if (user != null) LatLng(user.lat, user.lon),
        for (final item in nearby)
          LatLng(item.guide.center.lat, item.guide.center.lon),
      ];
      if (points.length == 1) {
        _controller.move(points.first, 14);
        return;
      }
      _controller.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.all(36),
          maxZoom: 14,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = UserLocation.instance.fix;
    final nearby = _scored(user);
    return ColoredBox(
      color: const Color(0xFFE8E4DC),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _controller,
            options: MapOptions(
              initialCenter: user != null
                  ? LatLng(user.lat, user.lon)
                  : nearby.isNotEmpty
                      ? LatLng(
                          nearby.first.guide.center.lat,
                          nearby.first.guide.center.lon,
                        )
                      : const LatLng(55.75, 37.62),
              initialZoom: 13,
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
                  for (final item in nearby)
                    Marker(
                      point: LatLng(
                        item.guide.center.lat,
                        item.guide.center.lon,
                      ),
                      width: 96,
                      height: 64,
                      child: GestureDetector(
                        onTap: () => widget.onGuideTap(item.guide),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: idleFill,
                                shape: BoxShape.circle,
                                border: Border.all(color: idleStroke, width: 2),
                              ),
                              child: const Icon(
                                Icons.headset,
                                size: 14,
                                color: idleStroke,
                              ),
                            ),
                            Text(
                              item.guide.city,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: idleStroke,
                                shadows: [
                                  Shadow(color: Colors.white, blurRadius: 6),
                                ],
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

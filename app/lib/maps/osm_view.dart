import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/guide.dart';
import 'stop_chip.dart';
import 'user_dot.dart';
import 'user_location.dart';

class GuideOsmMap extends StatefulWidget {
  const GuideOsmMap({
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
  State<GuideOsmMap> createState() => _GuideOsmMapState();
}

class _GuideOsmMapState extends State<GuideOsmMap> {
  final _controller = MapController();

  @override
  void didUpdateWidget(GuideOsmMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.guide.id != widget.guide.id) {
      _controller.move(
        LatLng(widget.guide.center.lat, widget.guide.center.lon),
        14,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stops = widget.guide.stops;
    final user = widget.user;
    return FlutterMap(
      mapController: _controller,
      options: MapOptions(
        initialCenter: LatLng(
          widget.guide.center.lat,
          widget.guide.center.lon,
        ),
        initialZoom: 14,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.solovyshka.audio_guide',
        ),
        if (stops.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: [
                  for (final stop in stops) LatLng(stop.lat, stop.lon),
                ],
                color: idleStroke.withValues(alpha: 0.55),
                strokeWidth: 3,
              ),
            ],
          ),
        if (user != null && (user.accuracy ?? 0) > 4)
          CircleLayer(
            circles: [
              CircleMarker(
                point: LatLng(user.lat, user.lon),
                radius: (user.accuracy ?? 20).clamp(6, 120),
                useRadiusInMeter: true,
                color: const Color(0x332A7DE1),
                borderColor: const Color(0x662A7DE1),
                borderStrokeWidth: 1,
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            for (final stop in stops)
              Marker(
                point: LatLng(stop.lat, stop.lon),
                width: 96,
                height: 72,
                child: GestureDetector(
                  onTap: () => widget.onStopTap(stop.order),
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      StopChip(
                        number: stop.order,
                        active: stop.order == widget.currentIndex,
                      ),
                      if (stop.order == widget.currentIndex)
                        Positioned(
                          top: 42,
                          left: 0,
                          right: 0,
                          child: Text(
                            stop.name,
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
    );
  }
}

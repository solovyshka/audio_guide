import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/guide.dart';
import 'stop_chip.dart';

class GuideOsmMap extends StatefulWidget {
  const GuideOsmMap({
    super.key,
    required this.guide,
    required this.currentIndex,
    required this.onStopTap,
  });

  final Guide guide;
  final int currentIndex;
  final ValueChanged<int> onStopTap;

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
          ],
        ),
      ],
    );
  }
}

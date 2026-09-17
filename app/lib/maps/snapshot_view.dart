import 'package:flutter/material.dart';

import '../models/guide.dart';
import 'map_image.dart';
import 'stop_chip.dart';
import 'user_dot.dart';
import 'user_location.dart';

class GuideSnapshotMap extends StatelessWidget {
  const GuideSnapshotMap({
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
  Widget build(BuildContext context) {
    final url = guide.mapUrl;
    if (url == null || url.isEmpty) {
      return const Center(child: Text('Нет снимка карты'));
    }
    final bounds = guide.bounds;
    return LayoutBuilder(
      builder: (context, constraints) {
        final pane = Size(constraints.maxWidth, constraints.maxHeight);
        final fitted = applyBoxFit(
          BoxFit.contain,
          Size(bounds.width.toDouble(), bounds.height.toDouble()),
          pane,
        );
        final dest = fitted.destination;
        final dx = (pane.width - dest.width) / 2;
        final dy = (pane.height - dest.height) / 2;
        return InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: SizedBox(
            width: pane.width,
            height: pane.height,
            child: Stack(
              children: [
                Positioned(
                  left: dx,
                  top: dy,
                  width: dest.width,
                  height: dest.height,
                  child: Image(
                    image: guideMapImage(url),
                    fit: BoxFit.fill,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: Color(0xFFE8E4DC),
                      child: Center(
                        child: Text('Не удалось загрузить снимок'),
                      ),
                    ),
                  ),
                ),
                for (final stop in guide.stops)
                  _pin(
                    stop: stop,
                    bounds: bounds,
                    origin: Offset(dx, dy),
                    mapSize: dest,
                    active: stop.order == currentIndex,
                    onTap: () => onStopTap(stop.order),
                  ),
                if (user != null)
                  _userPin(
                    user: user!,
                    bounds: bounds,
                    origin: Offset(dx, dy),
                    mapSize: dest,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

Widget _pin({
  required Stop stop,
  required MapBounds bounds,
  required Offset origin,
  required Size mapSize,
  required bool active,
  required VoidCallback onTap,
}) {
  final lonSpan = bounds.lonMax - bounds.lonMin;
  final latSpan = bounds.latMax - bounds.latMin;
  if (lonSpan <= 0 || latSpan <= 0) {
    return const SizedBox.shrink();
  }
  final x = origin.dx + (stop.lon - bounds.lonMin) / lonSpan * mapSize.width;
  final y = origin.dy + (bounds.latMax - stop.lat) / latSpan * mapSize.height;
  const hit = 48.0;
  return Positioned(
    left: x - hit / 2,
    top: y - hit / 2,
    width: hit,
    height: hit,
    child: GestureDetector(
      onTap: onTap,
      child: Center(
        child: StopChip(number: stop.order, active: active),
      ),
    ),
  );
}

Widget _userPin({
  required UserFix user,
  required MapBounds bounds,
  required Offset origin,
  required Size mapSize,
}) {
  final lonSpan = bounds.lonMax - bounds.lonMin;
  final latSpan = bounds.latMax - bounds.latMin;
  if (lonSpan <= 0 || latSpan <= 0) {
    return const SizedBox.shrink();
  }
  if (user.lat < bounds.latMin ||
      user.lat > bounds.latMax ||
      user.lon < bounds.lonMin ||
      user.lon > bounds.lonMax) {
    return const SizedBox.shrink();
  }
  final x = origin.dx + (user.lon - bounds.lonMin) / lonSpan * mapSize.width;
  final y = origin.dy + (bounds.latMax - user.lat) / latSpan * mapSize.height;
  return Positioned(
    left: x - 14,
    top: y - 14,
    width: 28,
    height: 28,
    child: const UserDot(),
  );
}

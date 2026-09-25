import 'package:flutter/material.dart';

import '../config.dart';
import '../models/guide.dart';
import 'available.dart';
import 'map_view_mode.dart';
import 'map_view_prefs.dart';
import 'location_hint.dart';
import 'osm_view.dart';
import 'user_location.dart';
import 'yandex_view.dart';

class GuideMap extends StatefulWidget {
  const GuideMap({
    super.key,
    required this.guide,
    required this.currentIndex,
    required this.onStopTap,
  });

  final Guide guide;
  final int currentIndex;
  final ValueChanged<int> onStopTap;

  @override
  State<GuideMap> createState() => _GuideMapState();
}

class _GuideMapState extends State<GuideMap> {
  late MapViewMode _mode = _fallback(null);

  bool get _hasYandex => yandexMapsSupported && mapkitApiKey.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _restore();
    UserLocation.instance.attach();
  }

  @override
  void dispose() {
    UserLocation.instance.detach();
    super.dispose();
  }

  @override
  void didUpdateWidget(GuideMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.guide.id != widget.guide.id) {
      setState(() => _mode = _fallback(_mode));
    }
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
        return Stack(
          children: [
            Positioned.fill(child: _body()),
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Align(
                alignment: Alignment.topCenter,
                child: _MapSwitcher(
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

  Widget _body() {
    final user = UserLocation.instance.fix;
    switch (_mode) {
      case MapViewMode.yandex:
        return GuideYandexMap(
          guide: widget.guide,
          currentIndex: widget.currentIndex,
          onStopTap: widget.onStopTap,
          user: user,
        );
      case MapViewMode.osm:
        return GuideOsmMap(
          guide: widget.guide,
          currentIndex: widget.currentIndex,
          onStopTap: widget.onStopTap,
          user: user,
        );
    }
  }
}

class _MapSwitcher extends StatelessWidget {
  const _MapSwitcher({
    required this.mode,
    required this.hasYandex,
    required this.onChanged,
  });

  final MapViewMode mode;
  final bool hasYandex;
  final ValueChanged<MapViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xF2F7F4EE),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _chip('OSM', MapViewMode.osm),
            if (hasYandex) _chip('Яндекс', MapViewMode.yandex),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, MapViewMode value) {
    final selected = mode == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton(
        onPressed: () => onChanged(value),
        style: TextButton.styleFrom(
          foregroundColor: selected ? Colors.white : const Color(0xFF1F4B3A),
          backgroundColor:
              selected ? const Color(0xFF1F4B3A) : Colors.transparent,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          shape: const StadiumBorder(),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

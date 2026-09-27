import 'package:flutter/material.dart';

import 'map_view_mode.dart';

class MapViewSwitcher extends StatelessWidget {
  const MapViewSwitcher({
    super.key,
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
            if (hasYandex) _chip('Яндекс', MapViewMode.yandex),
            _chip('OSM', MapViewMode.osm),
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

import 'package:flutter/material.dart';

class MapControls extends StatelessWidget {
  const MapControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onLocate,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final Future<void> Function() onLocate;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: const Color(0xF2F7F4EE),
          elevation: 2,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _button(
                icon: Icons.add,
                tooltip: 'Приблизить',
                onPressed: onZoomIn,
              ),
              const Divider(height: 1, indent: 8, endIndent: 8),
              _button(
                icon: Icons.remove,
                tooltip: 'Отдалить',
                onPressed: onZoomOut,
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: const Color(0xF2F7F4EE),
          elevation: 2,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: IconButton(
            tooltip: 'Моё местоположение',
            onPressed: () => onLocate(),
            icon: const Icon(Icons.my_location),
            color: const Color(0xFF1F4B3A),
          ),
        ),
      ],
    );
  }

  Widget _button({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
      color: const Color(0xFF1F4B3A),
      constraints: const BoxConstraints.tightFor(width: 42, height: 42),
      padding: EdgeInsets.zero,
    );
  }
}

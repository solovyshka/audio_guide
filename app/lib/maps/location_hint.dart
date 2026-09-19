import 'package:flutter/material.dart';

import 'user_location.dart';

class LocationHint extends StatelessWidget {
  const LocationHint({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: UserLocation.instance,
      builder: (context, _) {
        final gps = UserLocation.instance;
        if (gps.fix != null) {
          return const SizedBox.shrink();
        }
        final (label, action) = switch (gps.phase) {
          UserLocationPhase.denied => (
              'Нет доступа к геолокации',
              gps.openSettings,
            ),
          UserLocationPhase.disabled => (
              'Включите геолокацию',
              gps.openSettings,
            ),
          _ => ('Определяю местоположение…', gps.retry),
        };
        return Material(
          color: const Color(0xE6F7F4EE),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: action,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F4B3A),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

import '../config.dart';
import '../models/guide.dart';
import 'available.dart';
import 'osm_view.dart';
import 'yandex_view.dart';

class GuideMap extends StatelessWidget {
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
  Widget build(BuildContext context) {
    if (yandexMapsSupported && mapkitApiKey.isNotEmpty) {
      return GuideYandexMap(
        guide: guide,
        currentIndex: currentIndex,
        onStopTap: onStopTap,
      );
    }
    return GuideOsmMap(
      guide: guide,
      currentIndex: currentIndex,
      onStopTap: onStopTap,
    );
  }
}

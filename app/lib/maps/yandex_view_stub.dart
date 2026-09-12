import 'package:flutter/material.dart';

import '../models/guide.dart';

class GuideYandexMap extends StatelessWidget {
  const GuideYandexMap({
    super.key,
    required this.guide,
    required this.onStopTap,
  });

  final Guide guide;
  final ValueChanged<int> onStopTap;

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand();
  }
}

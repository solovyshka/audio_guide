import 'package:flutter/material.dart';

import '../models/guide.dart';
import 'user_location.dart';

class GuideYandexMap extends StatelessWidget {
  const GuideYandexMap({
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
    return const SizedBox.expand();
  }
}

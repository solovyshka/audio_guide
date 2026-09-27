import 'package:flutter/material.dart';

import '../models/city.dart';
import 'user_location.dart';

class CityYandexMap extends StatelessWidget {
  const CityYandexMap({
    super.key,
    required this.city,
    this.selectedId,
    required this.onPlaceTap,
    this.user,
  });

  final City city;
  final String? selectedId;
  final ValueChanged<CityPlace> onPlaceTap;
  final UserFix? user;

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}

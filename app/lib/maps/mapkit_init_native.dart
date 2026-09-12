import 'package:yandex_maps_mapkit_lite/init.dart' as mapkit_init;

import 'available.dart';

Future<void> initMapkitIfNeeded(String apiKey) async {
  if (!yandexMapsSupported || apiKey.isEmpty) {
    return;
  }
  await mapkit_init.initMapkit(apiKey: apiKey);
}

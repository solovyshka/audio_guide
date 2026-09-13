import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'api/client.dart';
import 'config.dart';
import 'maps/mapkit_init.dart';
import 'offline/guide_cache.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GuideCache.instance.init();
  await initMapkitIfNeeded(mapkitApiKey);
  runApp(const AudioGuideApp());
}

class AudioGuideApp extends StatelessWidget {
  const AudioGuideApp({super.key});

  @override
  Widget build(BuildContext context) {
    final api = GuideApi();
    return MaterialApp(
      title: 'Аудиогид',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F4B3A)),
        useMaterial3: true,
      ),
      builder: (context, child) {
        if (!_phonePreview) {
          return child ?? const SizedBox.shrink();
        }
        return ColoredBox(
          color: const Color(0xFFD7D2C8),
          child: Center(
            child: SizedBox(
              width: 390,
              height: 844,
              child: Material(
                elevation: 12,
                borderRadius: BorderRadius.circular(28),
                clipBehavior: Clip.antiAlias,
                child: child,
              ),
            ),
          ),
        );
      },
      home: HomeScreen(api: api),
    );
  }
}

bool get _phonePreview =>
    kIsWeb || defaultTargetPlatform == TargetPlatform.windows;

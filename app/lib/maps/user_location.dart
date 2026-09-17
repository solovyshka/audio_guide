import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class UserFix {
  const UserFix({
    required this.lat,
    required this.lon,
    this.accuracy,
  });

  final double lat;
  final double lon;
  final double? accuracy;
}

class UserLocation extends ChangeNotifier {
  UserLocation._();

  static final UserLocation instance = UserLocation._();

  UserFix? fix;
  int _leases = 0;
  StreamSubscription<Position>? _sub;
  Future<void>? _starting;

  Future<void> attach() async {
    _leases += 1;
    if (_leases > 1) {
      return;
    }
    _starting = _start();
    await _starting;
  }

  Future<void> detach() async {
    _leases = _leases > 0 ? _leases - 1 : 0;
    if (_leases > 0) {
      return;
    }
    await _sub?.cancel();
    _sub = null;
    _starting = null;
  }

  Future<void> _start() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever ||
          permission == LocationPermission.unableToDetermine) {
        return;
      }
      try {
        final last = await Geolocator.getLastKnownPosition(
          forceAndroidLocationManager: true,
        );
        if (last != null) {
          _setFix(last);
        }
      } catch (_) {}
      await _sub?.cancel();
      _sub = Geolocator.getPositionStream(locationSettings: _settings()).listen(
        _setFix,
        onError: (_) {},
      );
      Geolocator.getCurrentPosition(locationSettings: _settings()).then(
        _setFix,
        onError: (_, __) {},
      );
    } catch (_) {}
  }

  void _setFix(Position position) {
    fix = UserFix(
      lat: position.latitude,
      lon: position.longitude,
      accuracy: position.accuracy,
    );
    notifyListeners();
  }

  LocationSettings _settings() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 4,
        forceLocationManager: true,
        intervalDuration: const Duration(seconds: 3),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 4,
    );
  }
}

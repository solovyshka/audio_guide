import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
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

enum UserLocationPhase { idle, locating, ready, denied, disabled }

class UserLocation extends ChangeNotifier with WidgetsBindingObserver {
  UserLocation._();

  static final UserLocation instance = UserLocation._();

  UserFix? fix;
  UserLocationPhase phase = UserLocationPhase.idle;

  int _leases = 0;
  StreamSubscription<Position>? _sub;
  Future<void>? _starting;
  Timer? _watchdog;
  bool _forceManager = false;
  bool _observing = false;

  Future<void> attach() async {
    _leases += 1;
    _observe(true);
    await Future<void>.delayed(Duration.zero);
    await _ensureStarted();
  }

  Future<void> detach() async {
    _leases = _leases > 0 ? _leases - 1 : 0;
    if (_leases > 0) {
      return;
    }
    _observe(false);
    await _stop();
  }

  Future<void> retry() async {
    await _stop();
    await _ensureStarted();
  }

  Future<void> openSettings() {
    if (phase == UserLocationPhase.disabled) {
      return Geolocator.openLocationSettings();
    }
    return Geolocator.openAppSettings();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || _leases <= 0) {
      return;
    }
    if (_sub == null) {
      unawaited(_ensureStarted());
      return;
    }
    if (fix == null) {
      unawaited(_probe(false));
      unawaited(_probe(true));
    }
  }

  Future<void> _ensureStarted() async {
    if (_sub != null) {
      return;
    }
    if (_starting != null) {
      await _starting;
      if (_sub != null) {
        return;
      }
    }
    _starting = _start();
    try {
      await _starting;
    } finally {
      _starting = null;
    }
  }

  Future<void> _stop() async {
    _watchdog?.cancel();
    _watchdog = null;
    await _sub?.cancel();
    _sub = null;
    _forceManager = false;
  }

  Future<void> _start() async {
    _setPhase(UserLocationPhase.locating);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _setPhase(UserLocationPhase.denied);
        return;
      }

      await _tryLastKnown(false);
      await _tryLastKnown(true);

      _listen(forceManager: false);
      unawaited(_probe(false));
      unawaited(_probe(true));

      _watchdog?.cancel();
      _watchdog = Timer(const Duration(seconds: 6), () {
        if (_leases == 0 || fix != null) {
          return;
        }
        _listen(forceManager: true);
        unawaited(_probe(true));
      });

      if (!await Geolocator.isLocationServiceEnabled() && fix == null) {
        _setPhase(UserLocationPhase.disabled);
      }
    } catch (_) {
      if (fix == null) {
        _setPhase(UserLocationPhase.disabled);
      }
    }
  }

  void _listen({required bool forceManager}) {
    if (_sub != null && _forceManager == forceManager) {
      return;
    }
    _forceManager = forceManager;
    unawaited(_sub?.cancel());
    _sub = Geolocator.getPositionStream(
      locationSettings: _settings(forceManager: forceManager),
    ).listen(
      (position) => _setFix(position, lastKnown: false),
      onError: (_) {
        if (!forceManager && _leases > 0) {
          _listen(forceManager: true);
        }
      },
    );
  }

  Future<void> _tryLastKnown(bool forceManager) async {
    try {
      final last = await Geolocator.getLastKnownPosition(
        forceAndroidLocationManager: forceManager,
      );
      if (last != null) {
        _setFix(last, lastKnown: true);
      }
    } catch (_) {}
  }

  Future<void> _probe(bool forceManager) async {
    try {
      final now = await Geolocator.getCurrentPosition(
        locationSettings: _settings(
          forceManager: forceManager,
          timeLimit: const Duration(seconds: 12),
        ),
      );
      _setFix(now, lastKnown: false);
    } catch (_) {}
  }

  void _setFix(Position position, {required bool lastKnown}) {
    final age = DateTime.now().toUtc().difference(position.timestamp.toUtc());
    if (lastKnown) {
      if (fix != null) {
        return;
      }
      if (age > const Duration(seconds: 20) || position.accuracy > 25) {
        return;
      }
    } else if (fix != null &&
        fix!.accuracy != null &&
        position.accuracy > (fix!.accuracy! + 25) &&
        age < const Duration(seconds: 2)) {
      return;
    }
    fix = UserFix(
      lat: position.latitude,
      lon: position.longitude,
      accuracy: position.accuracy,
    );
    _watchdog?.cancel();
    _watchdog = null;
    _setPhase(UserLocationPhase.ready);
  }

  void _setPhase(UserLocationPhase next) {
    phase = next;
    notifyListeners();
  }

  void _observe(bool on) {
    if (on && !_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    } else if (!on && _observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
  }

  LocationSettings _settings({
    required bool forceManager,
    Duration? timeLimit,
  }) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 1,
        forceLocationManager: forceManager,
        intervalDuration: const Duration(seconds: 1),
        timeLimit: timeLimit,
      );
    }
    return LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 1,
      timeLimit: timeLimit,
    );
  }
}

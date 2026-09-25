import 'package:flutter/material.dart';

import '../net/api_door.dart';
import 'app_release.dart';
import 'app_updater.dart';

class UpdateBanner extends StatefulWidget {
  const UpdateBanner({super.key, required this.release});

  final AppRelease release;

  @override
  State<UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<UpdateBanner> {
  final _updater = AppUpdater();
  bool _busy = false;
  String? _door;
  int _received = 0;
  int? _total;
  String? _error;

  Future<void> _run(String door) async {
    final label = ApiDoor.shortLabel(door);
    setState(() {
      _busy = true;
      _door = door;
      _error = null;
      _received = 0;
      _total = widget.release.sizeBytes;
    });
    try {
      final file = await _updater.download(
        widget.release,
        url: ApiDoor.updateUrl(door),
        onProgress: (received, total) {
          if (!mounted) {
            return;
          }
          setState(() {
            _received = received;
            _total = total;
          });
        },
      );
      await _updater.install(file);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _error = '$label: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _total ?? widget.release.sizeBytes;
    final fraction =
        total != null && total > 0 ? (_received / total).clamp(0.0, 1.0) : null;
    return Material(
      color: const Color(0xFF1F4B3A),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Доступна версия ${widget.release.versionName}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                for (final door in _updateDoors)
                  TextButton(
                    onPressed: _busy ? null : () => _run(door),
                    child: Text(
                      _busy && _door == door
                          ? 'Скачиваю ${ApiDoor.shortLabel(door)}…'
                          : ApiDoor.shortLabel(door),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
              ],
            ),
            if (_busy)
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 8),
                child: LinearProgressIndicator(
                  value: fraction,
                  color: Colors.white,
                  backgroundColor: Colors.white24,
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 8),
                child: Text(
                  _friendlyError(_error!),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

List<String> get _updateDoors {
  final doors = [...ApiDoor.doors];
  doors.sort((a, b) {
    final ar = ApiDoor.shortLabel(a) == 'RU' ? 0 : 1;
    final br = ApiDoor.shortLabel(b) == 'RU' ? 0 : 1;
    return ar.compareTo(br);
  });
  return doors;
}

String _friendlyError(String error) {
  final lower = error.toLowerCase();
  if (lower.contains('connection closed') ||
      lower.contains('clientexception') ||
      lower.contains('timeout') ||
      lower.contains('broken pipe')) {
    return 'Сеть оборвала загрузку. Нажмите «Обновить» ещё раз.';
  }
  return error.replaceFirst('Exception: ', '');
}

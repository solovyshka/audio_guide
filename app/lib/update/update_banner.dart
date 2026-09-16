import 'package:flutter/material.dart';

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
  int _received = 0;
  int? _total;
  String? _error;

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = null;
      _received = 0;
      _total = widget.release.sizeBytes;
    });
    try {
      final file = await _updater.download(
        widget.release,
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
      setState(() => _error = error.toString());
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
                TextButton(
                  onPressed: _busy ? null : _run,
                  child: Text(
                    _busy ? 'Скачиваю…' : 'Обновить',
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
                  _error!,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

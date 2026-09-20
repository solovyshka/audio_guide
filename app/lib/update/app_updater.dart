import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../api/client.dart';
import '../net/chunked_download.dart';
import 'app_release.dart';

class AppUpdater {
  AppUpdater({GuideApi? api}) : _api = api ?? GuideApi();

  final GuideApi _api;

  Future<PackageInfo> localInfo() => PackageInfo.fromPlatform();

  Future<AppRelease> remoteRelease() async {
    final remote = await _api.fetchAppRelease();
    if (remote == null || remote.apkUrl.isEmpty) {
      throw Exception('Сервер не отдал version.json');
    }
    return remote;
  }

  Future<AppRelease?> latestIfNewer() async {
    final checked = await check();
    return checked.newer;
  }

  Future<({AppRelease remote, AppRelease? newer, PackageInfo local})>
      check() async {
    final remote = await remoteRelease();
    final info = await localInfo();
    final localCode = int.tryParse(info.buildNumber) ?? 0;
    final newer = !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android &&
        (remote.versionCode > localCode ||
            _nameNewer(remote.versionName, info.version));
    return (remote: remote, newer: newer ? remote : null, local: info);
  }

  Future<File> download(
    AppRelease release, {
    void Function(int received, int? total)? onProgress,
  }) async {
    final tmp = await getTemporaryDirectory();
    final dir = Directory('${tmp.path}/updates');
    await dir.create(recursive: true);
    final file = File('${dir.path}/audio_guide-${release.versionCode}.apk');
    if (await dir.exists()) {
      await for (final entity in dir.list()) {
        final path = entity.path;
        if (path == file.path || path == '${file.path}.part') {
          continue;
        }
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
    final client = downloadClient();
    try {
      await downloadFile(
        client: client,
        url: release.apkUrl,
        dest: file,
        chunkSize: 4 * 1024 * 1024,
        expectedSize: release.sizeBytes,
        onProgress: onProgress,
      );
    } finally {
      client.close();
    }
    final size = await file.length();
    if (release.sizeBytes != null && size != release.sizeBytes) {
      await file.delete();
      throw Exception(
        'Скачанный файл неполный ($size из ${release.sizeBytes} байт)',
      );
    }
    return file;
  }

  Future<void> install(File apk) async {
    final result = await OpenFilex.open(
      apk.path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw Exception(result.message);
    }
  }
}

bool _nameNewer(String remote, String local) {
  final a = remote.split('.').map((part) => int.tryParse(part) ?? 0).toList();
  final b = local.split('.').map((part) => int.tryParse(part) ?? 0).toList();
  final n = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < n; i++) {
    final left = i < a.length ? a[i] : 0;
    final right = i < b.length ? b[i] : 0;
    if (left != right) {
      return left > right;
    }
  }
  return false;
}

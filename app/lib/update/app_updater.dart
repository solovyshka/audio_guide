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

  Future<AppRelease?> latestIfNewer() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }
    final remote = await _api.fetchAppRelease();
    if (remote == null || remote.apkUrl.isEmpty) {
      return null;
    }
    final info = await PackageInfo.fromPlatform();
    final local = int.tryParse(info.buildNumber) ?? 0;
    if (remote.versionCode <= local) {
      return null;
    }
    return remote;
  }

  Future<File> download(
    AppRelease release, {
    void Function(int received, int? total)? onProgress,
  }) async {
    final tmp = await getTemporaryDirectory();
    final dir = Directory('${tmp.path}/updates');
    await dir.create(recursive: true);
    final file = File('${dir.path}/audio_guide.apk');
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

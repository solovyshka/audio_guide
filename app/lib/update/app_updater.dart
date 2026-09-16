import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../api/client.dart';
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
    if (await file.exists()) {
      await file.delete();
    }
    final request = http.Request('GET', Uri.parse(release.apkUrl));
    final client = http.Client();
    try {
      final response = await client.send(request);
      if (response.statusCode != 200) {
        throw Exception('Не удалось скачать обновление (${response.statusCode})');
      }
      final total = response.contentLength;
      final sink = file.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.stream) {
          sink.add(chunk);
          received += chunk.length;
          onProgress?.call(received, total ?? release.sizeBytes);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
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

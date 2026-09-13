import 'package:flutter/foundation.dart';

import '../api/client.dart';
import '../models/guide.dart';
import 'download_progress.dart';

class GuideCache extends ChangeNotifier {
  GuideCache._();

  static final GuideCache instance = GuideCache._();

  Future<void> init() async {}

  bool isDownloaded(String id) => false;

  int? localVersion(String id) => null;

  bool isDownloading(String id) => false;

  DownloadProgress? progressOf(String id) => null;

  Future<List<GuideSummary>> localCatalog() async => [];

  Future<Guide?> loadLocal(String id) async => null;

  Future<Guide> withLocalAudio(Guide guide) async => guide;

  Future<void> download(GuideApi api, String id) async {
    throw UnsupportedError('Скачивание недоступно в браузере');
  }

  Future<void> delete(String id) async {}
}

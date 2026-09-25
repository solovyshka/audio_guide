import 'dart:io';

import 'package:path_provider/path_provider.dart';

class ContentPackStore {
  static Future<File> _file() async {
    final root = await getApplicationDocumentsDirectory();
    return File('${root.path}/content-pack.json');
  }

  static Future<String?> read() async {
    final file = await _file();
    if (!await file.exists()) {
      return null;
    }
    return file.readAsString();
  }

  static Future<void> write(String text) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(text);
  }
}

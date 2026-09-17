import 'dart:io';

import 'package:flutter/widgets.dart';

ImageProvider guideMapImage(String url) {
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return NetworkImage(url);
  }
  return FileImage(File(url));
}

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

const kDownloadUserAgent =
    'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 Chrome/126.0.0.0 Mobile Safari/537.36';

http.Client downloadClient({
  Duration idleTimeout = const Duration(seconds: 45),
}) {
  final io = HttpClient()
    ..connectionTimeout = const Duration(seconds: 25)
    ..idleTimeout = idleTimeout
    ..userAgent = kDownloadUserAgent
    ..maxConnectionsPerHost = 4;
  return IOClient(io);
}

Future<void> downloadFile({
  required http.Client client,
  required String url,
  required File dest,
  int chunkSize = 512 * 1024,
  int attempts = 10,
  int? expectedSize,
  void Function(int received, int? total)? onProgress,
}) async {
  await dest.parent.create(recursive: true);
  final part = File('${dest.path}.part');
  var total = expectedSize;
  var received = 0;
  if (await dest.exists()) {
    received = await dest.length();
    if (received > 0 && (total == null || received == total)) {
      onProgress?.call(received, total ?? received);
      return;
    }
    await dest.delete();
    received = 0;
  }
  if (await part.exists()) {
    received = await part.length();
    if (total != null && received > total) {
      await part.delete();
      received = 0;
    } else if (total != null && received == total) {
      await part.rename(dest.path);
      onProgress?.call(received, total);
      return;
    }
  }

  final uri = Uri.parse(url);
  RandomAccessFile? raf;
  try {
    raf = await part.open(mode: FileMode.writeOnlyAppend);
    await raf.setPosition(received);
    onProgress?.call(received, total);
    while (total == null || received < total) {
      final want =
          total == null ? chunkSize : math.min(chunkSize, total - received);
      if (want <= 0) {
        break;
      }
      final piece = await _getRange(
        client,
        uri,
        start: received,
        length: want,
        attempts: attempts,
      );
      total ??= piece.total;
      if (piece.bytes.isEmpty) {
        break;
      }
      await raf.writeFrom(piece.bytes);
      received += piece.bytes.length;
      onProgress?.call(received, total);
      if (total == null && piece.bytes.length < want) {
        break;
      }
    }
  } finally {
    await raf?.close();
  }

  if (total != null && received < total) {
    throw Exception(
      'Сеть оборвала загрузку (${_mb(received)} из ${_mb(total)} МБ). Повторите — продолжим.',
    );
  }
  if (received <= 0) {
    throw Exception('Не удалось скачать файл');
  }
  if (await dest.exists()) {
    await dest.delete();
  }
  await part.rename(dest.path);
}

class _Piece {
  const _Piece(this.bytes, this.total);
  final Uint8List bytes;
  final int? total;
}

Future<_Piece> _getRange(
  http.Client client,
  Uri url, {
  required int start,
  required int length,
  required int attempts,
}) async {
  Object? lastError;
  for (var attempt = 0; attempt < attempts; attempt++) {
    try {
      final request = http.Request('GET', url);
      request.headers['User-Agent'] = kDownloadUserAgent;
      request.headers['Range'] = 'bytes=$start-${start + length - 1}';
      request.headers['Accept'] = '*/*';
      request.headers['Cache-Control'] = 'no-cache';
      final response = await client.send(request).timeout(
        const Duration(seconds: 30),
      );
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw Exception('Не удалось скачать (${response.statusCode})');
      }
      if (response.statusCode == 200 && start != 0) {
        throw Exception('Сервер не отдал докачку (Range)');
      }
      final total = _totalOf(response, start);
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.stream.timeout(
        const Duration(seconds: 45),
      )) {
        builder.add(chunk);
        if (builder.length >= length) {
          break;
        }
      }
      var data = builder.takeBytes();
      if (data.length > length) {
        data = Uint8List.fromList(data.sublist(0, length));
      }
      return _Piece(data, total);
    } catch (error) {
      lastError = error;
      await Future<void>.delayed(
        Duration(milliseconds: 700 * (attempt + 1)),
      );
    }
  }
  throw lastError ?? Exception('Не удалось скачать файл');
}

int? _totalOf(http.StreamedResponse response, int start) {
  final range = response.headers['content-range'];
  if (range != null) {
    final slash = range.lastIndexOf('/');
    if (slash >= 0) {
      final raw = range.substring(slash + 1).trim();
      return int.tryParse(raw);
    }
  }
  if (response.statusCode == 200) {
    final length = response.contentLength;
    if (length != null) {
      return start + length;
    }
  }
  return null;
}

String _mb(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(1);

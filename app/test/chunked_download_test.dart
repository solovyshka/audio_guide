import 'dart:io';

import 'package:audio_guide/net/chunked_download.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('continues through a fallback URL and keeps using the working source',
      () async {
    final broken = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final working = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final temp = await Directory.systemTemp.createTemp('audio-guide-test-');
    final destination = File('${temp.path}/audio.bin');
    var brokenRequests = 0;
    var workingRequests = 0;
    const content = <int>[1, 2, 3, 4, 5, 6, 7, 8];

    broken.listen((request) {
      brokenRequests++;
      request.response.statusCode = HttpStatus.serviceUnavailable;
      request.response.close();
    });
    working.listen((request) {
      workingRequests++;
      final range = request.headers.value(HttpHeaders.rangeHeader)!;
      final match = RegExp(r'bytes=(\d+)-(\d+)').firstMatch(range)!;
      final start = int.parse(match.group(1)!);
      final end = int.parse(match.group(2)!);
      request.response
        ..statusCode = HttpStatus.partialContent
        ..headers.set(
          HttpHeaders.contentRangeHeader,
          'bytes $start-$end/${content.length}',
        )
        ..add(content.sublist(start, end + 1))
        ..close();
    });

    try {
      final client = downloadClient();
      try {
        await downloadFile(
          client: client,
          url: 'http://${broken.address.host}:${broken.port}/audio.bin',
          fallbackUrls: [
            'http://${working.address.host}:${working.port}/audio.bin',
          ],
          dest: destination,
          chunkSize: 4,
          attempts: 4,
        );
      } finally {
        client.close();
      }

      expect(await destination.readAsBytes(), content);
      expect(brokenRequests, 1);
      expect(workingRequests, 2);
    } finally {
      await broken.close(force: true);
      await working.close(force: true);
      await temp.delete(recursive: true);
    }
  });
}

import 'package:audio_guide/net/api_door.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late String originalDoor;

  setUp(() {
    originalDoor = ApiDoor.current;
  });

  tearDown(() {
    ApiDoor.current = originalDoor;
  });

  test('pin moves a public media URL to the selected door', () {
    ApiDoor.current = 'https://vladislavsolovei.ru/audio';

    expect(
      ApiDoor.pin(
        'https://audio.solovyshka.com/media/guides/test/audio/intro.wav',
      ),
      'https://vladislavsolovei.ru/audio/media/guides/test/audio/intro.wav',
    );
  });

  test('failoverUrls keeps the selected door first and preserves the path', () {
    ApiDoor.current = 'https://vladislavsolovei.ru/audio';

    expect(
      ApiDoor.failoverUrls(
        'https://audio.solovyshka.com/media/guides/test/audio/intro.wav',
      ),
      [
        'https://vladislavsolovei.ru/audio/media/guides/test/audio/intro.wav',
        'https://audio.solovyshka.com/media/guides/test/audio/intro.wav',
      ],
    );
  });

  test('failoverUrls does not rewrite an unrelated host', () {
    const url = 'https://example.com/audio.wav';
    expect(ApiDoor.failoverUrls(url), [url]);
  });
}

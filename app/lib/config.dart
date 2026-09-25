import 'secrets.dart';

const apiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://audio.solovyshka.com',
);

/// Public doors. The app probes each with a tiny /health and keeps the
/// one that answers, preferring the faster complete response.
const apiDoors = <String>[
  'https://audio.solovyshka.com',
  'https://vladislavsolovei.ru/audio',
];

const mapkitApiKey = String.fromEnvironment(
  'MAPKIT_API_KEY',
  defaultValue: mapkitApiKeyLocal,
);

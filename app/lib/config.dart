import 'secrets.dart';

const apiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'https://audio.solovyshka.com',
);

const mapkitApiKey = String.fromEnvironment(
  'MAPKIT_API_KEY',
  defaultValue: mapkitApiKeyLocal,
);

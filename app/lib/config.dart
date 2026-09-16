import 'secrets.dart';

const apiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://51.254.219.211',
);

const mapkitApiKey = String.fromEnvironment(
  'MAPKIT_API_KEY',
  defaultValue: mapkitApiKeyLocal,
);

import 'secrets.dart';

const apiBase = String.fromEnvironment(
  'API_BASE',
  defaultValue: 'http://161.104.53.72',
);

const mapkitApiKey = String.fromEnvironment(
  'MAPKIT_API_KEY',
  defaultValue: mapkitApiKeyLocal,
);

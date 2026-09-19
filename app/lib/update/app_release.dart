class AppRelease {
  const AppRelease({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    this.sizeBytes,
  });

  final int versionCode;
  final String versionName;
  final String apkUrl;
  final int? sizeBytes;

  factory AppRelease.fromJson(Map<String, dynamic> json) {
    return AppRelease(
      versionCode: _asInt(json['versionCode'] ?? json['version_code']),
      versionName: '${json['versionName'] ?? json['version_name'] ?? ''}',
      apkUrl: '${json['apkUrl'] ?? json['apk_url'] ?? ''}',
      sizeBytes: _asIntOrNull(json['sizeBytes'] ?? json['size_bytes']),
    );
  }
}

int _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse('$value') ?? 0;
}

int? _asIntOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  return _asInt(value);
}

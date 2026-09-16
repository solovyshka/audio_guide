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
      versionCode: (json['versionCode'] ?? json['version_code'] ?? 0) as int,
      versionName: (json['versionName'] ?? json['version_name'] ?? '') as String,
      apkUrl: (json['apkUrl'] ?? json['apk_url'] ?? '') as String,
      sizeBytes: json['sizeBytes'] as int? ?? json['size_bytes'] as int?,
    );
  }
}

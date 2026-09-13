class DownloadProgress {
  const DownloadProgress({
    required this.completed,
    required this.total,
    this.label,
  });

  final int completed;
  final int total;
  final String? label;

  double? get fraction => total <= 0 ? null : completed / total;
}

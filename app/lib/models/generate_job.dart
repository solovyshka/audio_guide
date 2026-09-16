class GenerateJob {
  const GenerateJob({
    required this.id,
    required this.city,
    required this.status,
    required this.step,
    this.length = 'short',
    this.guideId,
    this.error,
  });

  final String id;
  final String city;
  final String status;
  final String step;
  final String length;
  final String? guideId;
  final String? error;

  bool get isDone => status == 'done';
  bool get isError => status == 'error';
  bool get isActive => status == 'queued' || status == 'running';
  bool get isLong => length == 'long';
  String get lengthLabel => isLong ? 'длинный' : 'короткий';

  static bool idMatchesLength(String id, String length) {
    final isLongId = id.endsWith('-long');
    return length == 'long' ? isLongId : !isLongId;
  }

  factory GenerateJob.fromJson(Map<String, dynamic> json) {
    return GenerateJob(
      id: json['id'] as String,
      city: json['city'] as String? ?? '',
      status: json['status'] as String? ?? '',
      step: json['step'] as String? ?? '',
      length: json['length'] as String? ?? 'short',
      guideId: json['guideId'] as String? ?? json['guide_id'] as String?,
      error: json['error'] as String?,
    );
  }
}

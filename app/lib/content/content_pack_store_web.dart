class ContentPackStore {
  static String? _memory;

  static Future<String?> read() async => _memory;

  static Future<void> write(String text) async {
    _memory = text;
  }
}

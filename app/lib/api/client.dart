import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/generate_job.dart';
import '../models/guide.dart';
import '../update/app_release.dart';

class GuideApi {
  GuideApi({String? baseUrl})
      : baseUrl = (baseUrl ?? apiBase).replaceAll(RegExp(r'/$'), '');

  final String baseUrl;

  Future<List<GuideSummary>> listGuides() async {
    final response = await http.get(Uri.parse('$baseUrl/guides'));
    return _decodeList(response);
  }

  Future<List<GuideSummary>> search(String query) async {
    final uri = Uri.parse('$baseUrl/guides/search').replace(
      queryParameters: {'q': query},
    );
    final response = await http.get(uri);
    return _decodeList(response);
  }

  Future<Map<String, dynamic>> getGuideJson(String id) async {
    final response = await http.get(Uri.parse('$baseUrl/guides/$id'));
    if (response.statusCode != 200) {
      throw Exception('Гид не найден');
    }
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<Guide> getGuide(String id) async {
    return Guide.fromJson(await getGuideJson(id));
  }

  Future<GenerateJob> startGenerate(String city, {String length = 'short'}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/guides/generate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'city': city, 'length': length}),
    );
    if (response.statusCode != 200 && response.statusCode != 202) {
      throw Exception(_errorMessage(response, 'Не удалось начать сборку гида'));
    }
    return GenerateJob.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<GenerateJob> generateStatus(String jobId) async {
    final response = await http.get(Uri.parse('$baseUrl/guides/jobs/$jobId'));
    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response, 'Не удалось узнать статус сборки'));
    }
    return GenerateJob.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  String _errorMessage(http.Response response, String fallback) {
    try {
      final payload =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final detail = payload['detail'];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
    } catch (_) {}
    return '$fallback (${response.statusCode})';
  }

  Future<AppRelease?> fetchAppRelease() async {
    final response = await http.get(Uri.parse('$baseUrl/app/version.json'));
    if (response.statusCode != 200) {
      return null;
    }
    final payload =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    return AppRelease.fromJson(payload);
  }

  List<GuideSummary> _decodeList(http.Response response) {
    if (response.statusCode != 200) {
      throw Exception('Сервер недоступен (${response.statusCode})');
    }
    final payload = jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return payload
        .map((item) => GuideSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

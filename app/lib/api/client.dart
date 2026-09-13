import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/guide.dart';

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

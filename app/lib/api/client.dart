import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/area.dart';
import '../models/city.dart';
import '../models/generate_job.dart';
import '../models/guide.dart';
import '../net/api_door.dart';
import '../update/app_release.dart';

class GuideApi {
  GuideApi({String? baseUrl})
      : baseUrl = (baseUrl ?? ApiDoor.current).replaceAll(RegExp(r'/$'), '');

  final String baseUrl;

  Future<List<GuideSummary>> listGuides() async {
    final response = await http.get(Uri.parse('$baseUrl/guides'));
    return _decodeGuides(response);
  }

  Future<List<GuideSummary>> search(String query) async {
    final uri = Uri.parse('$baseUrl/guides/search').replace(
      queryParameters: {'q': query},
    );
    final response = await http.get(uri);
    return _decodeGuides(response);
  }

  Future<List<CitySummary>> listCities() async {
    final response = await http.get(Uri.parse('$baseUrl/cities'));
    return _decodeCities(response);
  }

  Future<List<AreaSummary>> listAreas() async {
    final response = await http.get(Uri.parse('$baseUrl/areas'));
    if (response.statusCode != 200) {
      throw Exception('Сервер недоступен (${response.statusCode})');
    }
    final payload =
        jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return payload
        .map((item) => AreaSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> getAreaJson(String id) async {
    final response = await http.get(Uri.parse('$baseUrl/areas/$id'));
    if (response.statusCode != 200) {
      throw Exception('Территория не найдена');
    }
    return _jsonMap(response);
  }

  Future<List<CitySummary>> searchCities(String query) async {
    final uri = Uri.parse('$baseUrl/cities/search').replace(
      queryParameters: {'q': query},
    );
    final response = await http.get(uri);
    return _decodeCities(response);
  }

  Future<Map<String, dynamic>> getCityJson(String id) async {
    final response = await http.get(Uri.parse('$baseUrl/cities/$id'));
    if (response.statusCode != 200) {
      throw Exception('Город не найден');
    }
    return _jsonMap(response);
  }

  Future<City> getCity(String id) async {
    return City.fromJson(await getCityJson(id));
  }

  Future<Map<String, dynamic>> getGuideJson(String id) async {
    final response = await http.get(Uri.parse('$baseUrl/guides/$id'));
    if (response.statusCode != 200) {
      throw Exception('Гид не найден');
    }
    return _jsonMap(response);
  }

  Future<Guide> getGuide(String id) async {
    return Guide.fromJson(await getGuideJson(id));
  }

  Future<GenerateJob> startGenerate(String city,
      {String length = 'short'}) async {
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

  Future<GenerateJob> startCityGenerate(String city) async {
    final response = await http.post(
      Uri.parse('$baseUrl/cities/generate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'city': city}),
    );
    if (response.statusCode != 200 && response.statusCode != 202) {
      throw Exception(
          _errorMessage(response, 'Не удалось начать сборку города'));
    }
    return GenerateJob.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<GenerateJob> generateStatus(String jobId) async {
    final response = await http.get(Uri.parse('$baseUrl/cities/jobs/$jobId'));
    if (response.statusCode == 404) {
      final fallback = await http.get(Uri.parse('$baseUrl/guides/jobs/$jobId'));
      return _decodeJob(fallback);
    }
    return _decodeJob(response);
  }

  GenerateJob _decodeJob(http.Response response) {
    if (response.statusCode != 200) {
      throw Exception(
          _errorMessage(response, 'Не удалось узнать статус сборки'));
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
    final uri = Uri.parse('$baseUrl/app/version.json').replace(
      queryParameters: {
        't': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
    final response = await http.get(
      uri,
      headers: const {
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    );
    if (response.statusCode != 200) {
      return null;
    }
    return AppRelease.fromJson(_jsonMap(response));
  }

  Map<String, dynamic> _jsonMap(http.Response response) {
    final payload =
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    ApiDoor.pinTree(payload);
    return payload;
  }

  List<GuideSummary> _decodeGuides(http.Response response) {
    if (response.statusCode != 200) {
      throw Exception('Сервер недоступен (${response.statusCode})');
    }
    final payload =
        jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return payload
        .map((item) => GuideSummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  List<CitySummary> _decodeCities(http.Response response) {
    if (response.statusCode != 200) {
      throw Exception('Сервер недоступен (${response.statusCode})');
    }
    final payload =
        jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    return payload
        .map((item) => CitySummary.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

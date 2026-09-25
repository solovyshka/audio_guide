import 'package:flutter/material.dart';

import '../api/client.dart';
import '../content/content_pack.dart';
import '../models/area.dart';
import '../models/city.dart';
import 'city_screen.dart';
import 'guide_screen.dart';

class AreaScreen extends StatefulWidget {
  const AreaScreen({
    super.key,
    required this.api,
    required this.areaId,
  });

  final GuideApi api;
  final String areaId;

  @override
  State<AreaScreen> createState() => _AreaScreenState();
}

class _AreaScreenState extends State<AreaScreen> {
  AreaSummary? _area;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      var area = ContentPack.instance.area(widget.areaId);
      area ??=
          AreaSummary.fromJson(await widget.api.getAreaJson(widget.areaId));
      if (!mounted) return;
      setState(() {
        _area = area;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить территорию';
        _loading = false;
      });
    }
  }

  void _openArea(String id) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AreaScreen(api: widget.api, areaId: id),
      ),
    );
  }

  void _openCity(CitySummary city) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CityScreen(
          api: widget.api,
          cityId: city.id,
          guides: ContentPack.instance.guides,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final area = _area;
    return Scaffold(
      appBar: AppBar(title: Text(area?.title ?? 'Страна')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : area == null
              ? Center(child: Text(_error ?? 'Территория не найдена'))
              : _content(area),
    );
  }

  Widget _content(AreaSummary area) {
    final pack = ContentPack.instance;
    final regions =
        area.childAreaIds.map(pack.area).whereType<AreaSummary>().toList();
    final cities =
        area.cityIds.map(pack.citySummary).whereType<CitySummary>().toList();
    final places =
        area.placeIds.map(pack.citySummary).whereType<CitySummary>().toList();
    final routes =
        area.routeIds.map(pack.citySummary).whereType<CitySummary>().toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        if (area.subtitle != null)
          Text(
            area.subtitle!,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        if (area.summary.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(area.summary, style: const TextStyle(height: 1.45)),
        ],
        const SizedBox(height: 16),
        _overview(area),
        if (regions.isNotEmpty) ...[
          const SizedBox(height: 20),
          _heading('Регионы'),
          ...regions.map(_regionTile),
        ],
        if (cities.isNotEmpty) ...[
          const SizedBox(height: 20),
          _heading('Города'),
          ...cities
              .map((city) => _cityTile(city, Icons.location_city_outlined)),
        ],
        if (places.isNotEmpty || routes.isNotEmpty) ...[
          const SizedBox(height: 20),
          _heading('Другие места и маршруты'),
          ...places.map((city) => _cityTile(city, Icons.place_outlined)),
          ...routes.map((city) => _cityTile(city, Icons.route_outlined)),
        ],
      ],
    );
  }

  Widget _overview(AreaSummary area) {
    final guideId = area.overviewGuideId;
    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        leading: const Icon(Icons.headphones_outlined),
        title: Text('Общий гид: ${area.title}'),
        subtitle: Text(
          guideId == null
              ? 'Обзор территории подготовим отдельным аудиогидом'
              : 'История, устройство территории и основные направления',
        ),
        trailing: guideId == null ? null : const Icon(Icons.chevron_right),
        enabled: guideId != null,
        onTap: guideId == null
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        GuideScreen(api: widget.api, guideId: guideId),
                  ),
                );
              },
      ),
    );
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 6),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
      );

  Widget _regionTile(AreaSummary region) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: const Icon(Icons.map_outlined),
          title: Text(region.title),
          subtitle: region.subtitle == null ? null : Text(region.subtitle!),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openArea(region.id),
        ),
      );

  Widget _cityTile(CitySummary city, IconData icon) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(icon),
          title: Text(city.title),
          subtitle: city.subtitle == null ? null : Text(city.subtitle!),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openCity(city),
        ),
      );
}

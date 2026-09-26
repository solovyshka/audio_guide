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

class _AreaScreenState extends State<AreaScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  AreaSummary? _area;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 8, vsync: this);
    _open();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
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
    final hasDossier = !area.history.isEmpty ||
        !area.present.isEmpty ||
        area.sights.isNotEmpty ||
        area.nature.isNotEmpty ||
        area.culture.isNotEmpty ||
        area.leisure.isNotEmpty;
    if (!hasDossier) {
      return _sections(area, showHeader: true, showOverview: true);
    }
    return Column(
      children: [
        if (area.subtitle != null || area.summary.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (area.subtitle != null)
                  Text(
                    area.subtitle!,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                if (area.subtitle != null && area.summary.isNotEmpty)
                  const SizedBox(height: 8),
                if (area.summary.isNotEmpty)
                  Text(area.summary, style: const TextStyle(height: 1.4)),
              ],
            ),
          ),
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'История'),
              Tab(text: 'Настоящее'),
              Tab(text: 'Места'),
              Tab(text: 'Природа'),
              Tab(text: 'Культура'),
              Tab(text: 'Досуг'),
              Tab(text: 'Аудиогид'),
              Tab(text: 'Разделы'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _history(area),
              _present(area),
              _places(area.sights, 'Главные места пока не собраны'),
              _places(area.nature, 'Природные места пока не собраны'),
              _places(area.culture, 'Культурные места пока не собраны'),
              _places(area.leisure, 'Кофейни и рестораны пока не собраны'),
              _overviewTab(area),
              _sections(area),
            ],
          ),
        ),
      ],
    );
  }

  Widget _history(AreaSummary area) {
    final history = area.history;
    if (history.isEmpty) {
      return _empty('Историческая справка ещё не собрана');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (history.founded.isNotEmpty)
          Text(
            history.founded,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        if (history.founded.isNotEmpty) const SizedBox(height: 12),
        Text(history.summary, style: const TextStyle(height: 1.45)),
        if (history.events.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Главные даты',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (final event in history.events)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('${event.year} — ${event.text}'),
            ),
        ],
      ],
    );
  }

  Widget _present(AreaSummary area) {
    final present = area.present;
    if (present.isEmpty) {
      return _empty('Современная справка ещё не собрана');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        if (present.population.isNotEmpty)
          Text('Население: ${present.population}'),
        if (present.economy.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('Экономика: ${present.economy}'),
        ],
        if (present.summary.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(present.summary, style: const TextStyle(height: 1.45)),
        ],
      ],
    );
  }

  Widget _places(List<CityPlace> places, String empty) {
    if (places.isEmpty) {
      return _empty(empty);
    }
    return ListView.separated(
      itemCount: places.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, index) {
        final place = places[index];
        return ListTile(
          title: Text(place.name),
          subtitle: place.summary.isEmpty ? null : Text(place.summary),
          isThreeLine: place.summary.length > 80,
        );
      },
    );
  }

  Widget _empty(String text) => ListView(
        padding: const EdgeInsets.all(24),
        children: [Text(text, textAlign: TextAlign.center)],
      );

  Widget _overviewTab(AreaSummary area) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [_overview(area)],
      );

  Widget _sections(
    AreaSummary area, {
    bool showHeader = false,
    bool showOverview = false,
  }) {
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        if (showHeader && area.subtitle != null)
          Text(
            area.subtitle!,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        if (showHeader && area.summary.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(area.summary, style: const TextStyle(height: 1.45)),
        ],
        if (showOverview) ...[
          const SizedBox(height: 16),
          _overview(area),
        ],
        if (regions.isNotEmpty) ...[
          if (showHeader || showOverview) const SizedBox(height: 20),
          _heading('Регионы'),
          ...regions.map(_regionTile),
        ],
        if (cities.isNotEmpty) ...[
          if (regions.isNotEmpty || showHeader || showOverview)
            const SizedBox(height: 12),
          _heading('Города'),
          ...cities
              .map((city) => _cityTile(city, Icons.location_city_outlined)),
        ],
        if (places.isNotEmpty || routes.isNotEmpty) ...[
          if (regions.isNotEmpty ||
              cities.isNotEmpty ||
              showHeader ||
              showOverview)
            const SizedBox(height: 12),
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

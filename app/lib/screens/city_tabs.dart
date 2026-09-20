import 'package:flutter/material.dart';

import '../api/client.dart';
import '../models/city.dart';
import '../models/guide.dart';
import '../offline/guide_actions.dart';
import '../offline/guide_cache.dart';
import 'guide_screen.dart';

class CityTabs extends StatelessWidget {
  const CityTabs({
    super.key,
    required this.city,
    required this.controller,
    required this.api,
    required this.guides,
    required this.offline,
    required this.onGenerate,
    this.selectedPlaceId,
  });

  final City city;
  final TabController controller;
  final GuideApi api;
  final List<GuideSummary> guides;
  final bool offline;
  final VoidCallback onGenerate;
  final String? selectedPlaceId;

  GuideSummary? _guide(String? id) {
    if (id == null) {
      return null;
    }
    for (final guide in guides) {
      if (guide.id == id) {
        return guide;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: TabBar(
            controller: controller,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'История'),
              Tab(text: 'Настоящее'),
              Tab(text: 'Места'),
              Tab(text: 'Природа'),
              Tab(text: 'Культура'),
              Tab(text: 'Досуг'),
              Tab(text: 'Короткий'),
              Tab(text: 'Длинный'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: controller,
            children: [
              _history(context),
              _present(context),
              _places(context, city.sights, 'Городские достопримечательности пока не собраны'),
              _places(context, city.nature, 'Парки и смотровые пока не собраны'),
              _places(context, city.culture, 'Музеи и театры пока не собраны'),
              _places(context, city.leisure, 'Кофе, кондитерские и рестораны пока не собраны'),
              _guideTab(context, city.guides.short, 'Короткий аудиогид'),
              _guideTab(context, city.guides.long, 'Длинный аудиогид'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _empty(BuildContext context, String text) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(text, textAlign: TextAlign.center),
        if (!offline) ...[
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onGenerate,
            child: const Text('Собрать город'),
          ),
        ],
      ],
    );
  }

  Widget _history(BuildContext context) {
    final history = city.history;
    if (history.isEmpty) {
      return _empty(context, 'История города ещё не собрана');
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
          const Text(
            'Главные даты',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
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

  Widget _present(BuildContext context) {
    final present = city.present;
    if (present.isEmpty) {
      return _empty(context, 'Современный очерк ещё не собран');
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

  Widget _places(BuildContext context, List<CityPlace> places, String empty) {
    if (places.isEmpty) {
      return _empty(context, empty);
    }
    return ListView.separated(
      itemCount: places.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final place = places[index];
        final selected = place.id == selectedPlaceId;
        return ListTile(
          selected: selected,
          title: Text(place.name),
          subtitle: place.summary.isEmpty ? null : Text(place.summary),
          isThreeLine: place.summary.length > 80,
        );
      },
    );
  }

  Widget _guideTab(BuildContext context, String? guideId, String title) {
    if (guideId == null || guideId.isEmpty) {
      return _empty(context, '$title ещё не собран');
    }
    final summary = _guide(guideId);
    final minutes = summary == null
        ? null
        : (summary.durationSec / 60).ceil();
    final cache = GuideCache.instance;
    final downloading = cache.isDownloading(guideId);
    final downloaded = cache.isDownloaded(guideId);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(summary?.title ?? title),
          subtitle: Text(
            [
              if (summary?.subtitle != null) summary!.subtitle,
              if (summary != null)
                '${summary.stopsCount} точек · $minutes мин'
              else
                'Открыть маршрут',
            ].whereType<String>().join('\n'),
          ),
          isThreeLine: summary?.subtitle != null,
          leading: downloading
              ? const SizedBox(
                  width: 40,
                  height: 40,
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : summary == null
                  ? const Icon(Icons.headset)
                  : PopupMenuButton<GuideMenuAction>(
                      icon: const Icon(Icons.more_vert),
                      tooltip: 'Ещё',
                      onSelected: (action) => handleGuideMenu(
                        context: context,
                        api: api,
                        guide: summary,
                        action: action,
                      ),
                      itemBuilder: (_) => buildGuideMenuItems(summary),
                    ),
          trailing: downloaded
              ? const Icon(Icons.download_done, color: Color(0xFF1F4B3A))
              : const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GuideScreen(api: api, guideId: guideId),
              ),
            );
          },
        ),
      ],
    );
  }
}

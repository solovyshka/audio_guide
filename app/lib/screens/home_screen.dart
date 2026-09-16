import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../api/client.dart';
import '../models/guide.dart';
import '../offline/guide_actions.dart';
import '../offline/guide_cache.dart';
import '../update/app_release.dart';
import '../update/app_updater.dart';
import '../update/update_banner.dart';
import 'guide_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api});

  final GuideApi api;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  final _speech = SpeechToText();
  List<GuideSummary> _guides = [];
  bool _loading = true;
  String? _error;
  bool _offline = false;
  bool _listening = false;
  AppRelease? _update;

  @override
  void initState() {
    super.initState();
    GuideCache.instance.addListener(_onCache);
    _loadCatalog();
    _checkUpdate();
  }

  void _onCache() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final guides = await widget.api.listGuides();
      if (!mounted) return;
      setState(() {
        _guides = guides;
        _loading = false;
        _offline = false;
      });
    } catch (error) {
      final local = await GuideCache.instance.localCatalog();
      if (!mounted) return;
      if (local.isNotEmpty) {
        setState(() {
          _guides = local;
          _loading = false;
          _offline = true;
          _error = null;
        });
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _searchGuides(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final guides = query.trim().isEmpty
          ? await widget.api.listGuides()
          : await widget.api.search(query);
      if (!mounted) return;
      setState(() {
        _guides = guides;
        _loading = false;
        _offline = false;
      });
    } catch (error) {
      final needle = query.trim().toLowerCase();
      final local = await GuideCache.instance.localCatalog();
      final filtered = needle.isEmpty
          ? local
          : local
              .where(
                (guide) =>
                    guide.title.toLowerCase().contains(needle) ||
                    guide.city.toLowerCase().contains(needle) ||
                    (guide.subtitle?.toLowerCase().contains(needle) ?? false),
              )
              .toList();
      if (!mounted) return;
      if (filtered.isNotEmpty) {
        setState(() {
          _guides = filtered;
          _loading = false;
          _offline = true;
          _error = null;
        });
        return;
      }
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _checkUpdate() async {
    try {
      final release = await AppUpdater(api: widget.api).latestIfNewer();
      if (!mounted || release == null) {
        return;
      }
      setState(() => _update = release);
    } catch (_) {}
  }

  Future<void> _listen() async {
    final available = await _speech.initialize();
    if (!available) {
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      localeId: 'ru_RU',
      onResult: (result) {
        _search.text = result.recognizedWords;
        if (result.finalResult) {
          _speech.stop();
          setState(() => _listening = false);
          _searchGuides(result.recognizedWords);
        }
      },
    );
  }

  @override
  void dispose() {
    GuideCache.instance.removeListener(_onCache);
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Аудиогид')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: _searchGuides,
              decoration: InputDecoration(
                hintText: 'Город или место',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: _listening ? _speech.stop : _listen,
                  icon: Icon(_listening ? Icons.mic : Icons.mic_none),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          if (_update != null) UpdateBanner(release: _update!),
          if (_offline)
            const Material(
              color: Color(0xFFE8E4DC),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text('Нет сети — показаны скачанные гиды'),
              ),
            ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: TextButton(
          onPressed: _loadCatalog,
          child: Text('Не удалось загрузить каталог.\n$_error'),
        ),
      );
    }
    if (_guides.isEmpty) {
      return const Center(
        child: Text('По этому месту аудиогида пока нет'),
      );
    }
    return ListView.separated(
      itemCount: _guides.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final guide = _guides[index];
        final minutes = (guide.durationSec / 60).ceil();
        final cache = GuideCache.instance;
        final downloading = cache.isDownloading(guide.id);
        final downloaded = cache.isDownloaded(guide.id);
        return ListTile(
          leading: downloading
              ? const SizedBox(
                  width: 40,
                  height: 40,
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : PopupMenuButton<GuideMenuAction>(
                  icon: const Icon(Icons.more_vert),
                  tooltip: 'Ещё',
                  onSelected: (action) => handleGuideMenu(
                    context: context,
                    api: widget.api,
                    guide: guide,
                    action: action,
                  ),
                  itemBuilder: (_) => buildGuideMenuItems(guide),
                ),
          title: Text(guide.title),
          subtitle: Text(
            [
              if (guide.subtitle != null) guide.subtitle,
              '${guide.stopsCount} точек · $minutes мин',
            ].whereType<String>().join('\n'),
          ),
          isThreeLine: guide.subtitle != null,
          trailing: downloaded
              ? const Icon(Icons.download_done, color: Color(0xFF1F4B3A))
              : null,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => GuideScreen(api: widget.api, guideId: guide.id),
              ),
            );
          },
        );
      },
    );
  }
}

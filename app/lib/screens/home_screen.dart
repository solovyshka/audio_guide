import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../api/client.dart';
import '../maps/nearby_map.dart';
import '../models/generate_job.dart';
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
  List<GuideSummary> _catalog = [];
  bool _loading = true;
  String? _error;
  bool _offline = false;
  bool _listening = false;
  AppRelease? _update;
  GenerateJob? _job;

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
        _catalog = guides;
        _loading = false;
        _offline = false;
      });
    } catch (error) {
      final local = await GuideCache.instance.localCatalog();
      if (!mounted) return;
      if (local.isNotEmpty) {
        setState(() {
          _guides = local;
          _catalog = local;
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
        if (query.trim().isEmpty) {
          _catalog = guides;
        }
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
          SizedBox(
            height: 240,
            child: NearbyMap(
              guides: _catalog.isNotEmpty ? _catalog : _guides,
              onGuideTap: (guide) {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        GuideScreen(api: widget.api, guideId: guide.id),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _emptyGenerate(String query) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'По «$query» гида пока нет',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _startGenerate(query, 'short'),
              child: const Text('Короткий гид'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () => _startGenerate(query, 'long'),
              child: const Text('Длинный гид'),
            ),
            const SizedBox(height: 12),
            const Text(
              'Короткий — 6–8 точек, около часа пешком.\n'
              'Длинный — 15–30 точек, на 3–6 часов.\n'
              'Сборка занимает несколько минут.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _generating(String query) {
    final job = _job!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (job.isActive) const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              job.isError
                  ? (job.error ?? 'Не удалось собрать гид')
                  : 'Собираю ${job.lengthLabel} гид по «$query»',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              job.step,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
            if (job.isError) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _startGenerate(query, job.length),
                child: const Text('Повторить'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _generateMore(String query) {
    final hasShort = _guides.any((guide) => !guide.id.endsWith('-long'));
    final hasLong = _guides.any((guide) => guide.id.endsWith('-long'));
    if (hasShort && hasLong) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        children: [
          const Divider(height: 24),
          Text(
            'Собрать ещё гид по «$query»',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              if (!hasShort)
                OutlinedButton(
                  onPressed: () => _startGenerate(query, 'short'),
                  child: const Text('Короткий'),
                ),
              if (!hasLong)
                OutlinedButton(
                  onPressed: () => _startGenerate(query, 'long'),
                  child: const Text('Длинный'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _startGenerate(String city, String length) async {
    setState(() {
      _error = null;
      _job = null;
    });
    try {
      final job = await widget.api.startGenerate(city, length: length);
      if (!mounted) {
        return;
      }
      setState(() => _job = job);
      if (await _finishIfDone(job, length)) {
        return;
      }
      if (job.isError) {
        return;
      }
      await _pollJob(job.id, length);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _job = GenerateJob(
          id: '',
          city: city,
          status: 'error',
          step: 'Ошибка',
          length: length,
          error: error.toString(),
        );
      });
    }
  }

  Future<bool> _finishIfDone(GenerateJob job, String length) async {
    if (!job.isDone || job.guideId == null) {
      return false;
    }
    if (GenerateJob.idMatchesLength(job.guideId!, length)) {
      await _openGenerated(job.guideId!);
      return true;
    }
    if (!mounted) {
      return true;
    }
    setState(() {
      _job = GenerateJob(
        id: job.id,
        city: job.city,
        status: 'error',
        step: 'Ошибка',
        length: length,
        error: 'Сервер открыл другой формат гида, нажмите ещё раз',
      );
    });
    return true;
  }

  Future<void> _pollJob(String jobId, String length) async {
    final deadline = DateTime.now().add(const Duration(minutes: 25));
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) {
        return;
      }
      final job = await widget.api.generateStatus(jobId);
      if (!mounted) {
        return;
      }
      setState(() => _job = job);
      if (await _finishIfDone(job, length)) {
        return;
      }
      if (job.isError) {
        return;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _job = GenerateJob(
        id: jobId,
        city: _search.text.trim(),
        status: 'error',
        step: 'Ошибка',
        length: _job?.length ?? 'short',
        error: 'Сборка слишком долгая, попробуйте ещё раз',
      );
    });
  }

  Future<void> _openGenerated(String guideId) async {
    await _loadCatalog();
    if (!mounted) {
      return;
    }
    if (_search.text.trim().isNotEmpty) {
      await _searchGuides(_search.text);
      if (!mounted) {
        return;
      }
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GuideScreen(api: widget.api, guideId: guideId),
      ),
    );
  }

  Widget _body() {
    if (_job != null && (_job!.isActive || _job!.isError)) {
      return _generating(_search.text.trim());
    }
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
      final query = _search.text.trim();
      if (query.isEmpty || _offline) {
        return const Center(child: Text('По этому месту аудиогида пока нет'));
      }
      return _emptyGenerate(query);
    }
    final query = _search.text.trim();
    return ListView.separated(
      itemCount: _guides.length + (query.isNotEmpty && !_offline ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        if (index >= _guides.length) {
          return _generateMore(query);
        }
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

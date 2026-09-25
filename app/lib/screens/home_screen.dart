import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../api/client.dart';
import '../content/content_pack.dart';
import '../maps/user_location.dart';
import '../models/city.dart';
import '../models/generate_job.dart';
import '../models/guide.dart';
import '../offline/guide_cache.dart';
import '../update/app_release.dart';
import '../update/app_updater.dart';
import '../update/update_banner.dart';
import 'area_screen.dart';
import 'city_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api});

  final GuideApi api;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _search = TextEditingController();
  final _speech = SpeechToText();
  final _distance = const Distance();
  List<CitySummary> _cities = [];
  List<GuideSummary> _guides = [];
  bool _loading = true;
  String? _error;
  bool _offline = false;
  bool _listening = false;
  AppRelease? _update;
  GenerateJob? _job;
  bool _refreshingJson = false;
  int _sectionIndex = 0;

  @override
  void initState() {
    super.initState();
    GuideCache.instance.addListener(_onCache);
    UserLocation.instance
      ..addListener(_onLocation)
      ..attach();
    _loadCatalog();
    _checkUpdate();
  }

  void _onCache() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onLocation() {
    if (mounted) {
      setState(() {});
    }
  }

  List<CitySummary> _sorted(List<CitySummary> cities) {
    final user = UserLocation.instance.fix;
    if (user == null || cities.isEmpty) {
      return cities;
    }
    final scored = [
      for (final city in cities)
        (
          city: city,
          meters: _distance.as(
            LengthUnit.Meter,
            LatLng(user.lat, user.lon),
            LatLng(city.center.lat, city.center.lon),
          ),
        ),
    ]..sort((a, b) => a.meters.compareTo(b.meters));
    return [for (final item in scored) item.city];
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cities = ContentPack.instance.cities;
      final guides = ContentPack.instance.guides;
      if (!mounted) return;
      setState(() {
        _cities = cities;
        _guides = guides;
        _loading = false;
        _offline = false;
        _error = cities.isEmpty ? 'В сборке нет городов' : null;
      });
    } catch (error) {
      final local = await GuideCache.instance.localCities();
      final localGuides = await GuideCache.instance.localCatalog();
      if (!mounted) return;
      if (local.isNotEmpty) {
        setState(() {
          _cities = local;
          _guides = localGuides;
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

  Future<void> _searchCities(String query) async {
    final needle = query.trim();
    setState(() {
      _loading = true;
      _error = null;
      _job = null;
    });
    try {
      final cities = ContentPack.instance.search(needle);
      if (!mounted) return;
      setState(() {
        _cities = cities;
        _loading = false;
        _offline = false;
      });
    } catch (error) {
      final local = await GuideCache.instance.localCities();
      final filtered = needle.isEmpty
          ? local
          : local.where((city) {
              final hay = [
                city.id,
                city.title,
                city.city,
                city.subtitle ?? '',
                ...city.aliases,
              ].join(' ').toLowerCase();
              return hay.contains(needle.toLowerCase());
            }).toList();
      if (!mounted) return;
      if (filtered.isNotEmpty) {
        setState(() {
          _cities = filtered;
          _loading = false;
          _offline = true;
          _error = null;
        });
        return;
      }
      setState(() {
        _cities = [];
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openCity(CitySummary item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CityScreen(
          api: widget.api,
          cityId: item.id,
          guides: _guides,
        ),
      ),
    );
  }

  Future<void> _refreshJson() async {
    if (_refreshingJson) {
      return;
    }
    setState(() => _refreshingJson = true);
    try {
      await ContentPack.instance.refresh(widget.api);
      if (!mounted) {
        return;
      }
      setState(() {
        _cities = ContentPack.instance.search(_search.text);
        _guides = ContentPack.instance.guides;
        _offline = false;
        _error = null;
      });
      _toast('JSON обновлён');
    } catch (_) {
      if (!mounted) {
        return;
      }
      _toast('Не удалось обновить JSON');
    } finally {
      if (mounted) {
        setState(() => _refreshingJson = false);
      }
    }
  }

  Future<void> _checkUpdate({bool manual = false}) async {
    try {
      final checked = await AppUpdater(api: widget.api).check();
      if (!mounted) {
        return;
      }
      if (checked.newer != null) {
        setState(() => _update = checked.newer);
        if (manual) {
          _toast(
            'Доступна ${checked.remote.versionName} (${checked.remote.versionCode})',
          );
        }
        return;
      }
      if (manual) {
        _toast(
          'Сейчас ${checked.local.version} (${checked.local.buildNumber}), '
          'сервер ${checked.remote.versionName} (${checked.remote.versionCode})',
        );
      }
    } catch (_) {
      if (!mounted || !manual) {
        return;
      }
      _toast('Не удалось проверить обновление');
    }
  }

  Future<void> _showVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Версия'),
          content: Text('${info.version} (${info.buildNumber})'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _listen() async {
    final available = await _speech.initialize();
    if (!available) {
      return;
    }
    setState(() => _listening = true);
    await _speech.listen(
      listenOptions: SpeechListenOptions(localeId: 'ru_RU'),
      onResult: (result) {
        _search.text = result.recognizedWords;
        if (result.finalResult) {
          _speech.stop();
          setState(() => _listening = false);
          _searchCities(result.recognizedWords);
        }
      },
    );
  }

  @override
  void dispose() {
    GuideCache.instance.removeListener(_onCache);
    UserLocation.instance
      ..removeListener(_onLocation)
      ..detach();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showingCountries = _sectionIndex == 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(showingCountries ? 'Страны' : 'Города'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Меню',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'version') {
                _showVersion();
              } else if (value == 'update') {
                _checkUpdate(manual: true);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem<String>(
                value: 'version',
                child: Text('Версия'),
              ),
              PopupMenuItem<String>(
                value: 'update',
                child: Text('Проверить обновления'),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Обновить JSON',
            onPressed: _refreshingJson ? null : _refreshJson,
            icon: _refreshingJson
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: showingCountries ? _countriesBody() : _citiesBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _sectionIndex,
        onDestinationSelected: (index) => setState(() => _sectionIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.public_outlined),
            selectedIcon: Icon(Icons.public),
            label: 'Страны',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_city_outlined),
            selectedIcon: Icon(Icons.location_city),
            label: 'Города',
          ),
        ],
      ),
    );
  }

  Widget _citiesBody() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: _searchCities,
            decoration: InputDecoration(
              hintText: 'Город',
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
              child: Text('Нет сети — показаны сохранённые города'),
            ),
          ),
        Expanded(child: _body()),
      ],
    );
  }

  Widget _countriesBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final countries = ContentPack.instance.countries;
    if (countries.isEmpty) {
      return const Center(child: Text('Страны пока не собраны'));
    }
    return ListView.separated(
      itemCount: countries.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final country = countries[index];
        return ListTile(
          leading: const Icon(Icons.public_outlined),
          title: Text(country.title),
          subtitle: Text(
            [
              if (country.subtitle != null) country.subtitle,
              country.navigationMode == 'regional'
                  ? '${country.childAreaIds.length} регионов'
                  : '${country.cityIds.length} городов · '
                      '${country.placeIds.length + country.routeIds.length} мест и маршрутов',
            ].whereType<String>().join('\n'),
          ),
          isThreeLine: country.subtitle != null,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => AreaScreen(
                api: widget.api,
                areaId: country.id,
              ),
            ),
          ),
        );
      },
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
              'По «$query» города пока нет',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => _startGenerate(query),
              child: const Text('Собрать город'),
            ),
            const SizedBox(height: 12),
            const Text(
              'За один проход: история, настоящее, места, культура, '
              'досуг, короткий и длинный аудиогид.\n'
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
                  ? (job.error ?? 'Не удалось собрать город')
                  : 'Собираю город «$query»',
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
                onPressed: () => _startGenerate(query),
                child: const Text('Повторить'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _startGenerate(String cityName) async {
    setState(() {
      _error = null;
      _job = null;
    });
    try {
      final job = await widget.api.startCityGenerate(cityName);
      if (!mounted) {
        return;
      }
      setState(() => _job = job);
      if (await _finishIfDone(job)) {
        return;
      }
      if (job.isError) {
        return;
      }
      await _pollJob(job.id);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _job = GenerateJob(
          id: '',
          city: cityName,
          status: 'error',
          step: 'Ошибка',
          length: 'city',
          error: error.toString(),
        );
      });
    }
  }

  Future<bool> _finishIfDone(GenerateJob job) async {
    if (!job.isDone) {
      return false;
    }
    final cityId = job.cityId;
    if (mounted) {
      setState(() => _job = null);
    }
    await _loadCatalog();
    if (!mounted) {
      return true;
    }
    if (cityId != null && cityId.isNotEmpty) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => CityScreen(
            api: widget.api,
            cityId: cityId,
            guides: _guides,
          ),
        ),
      );
    }
    return true;
  }

  Future<void> _pollJob(String jobId) async {
    final deadline = DateTime.now().add(const Duration(minutes: 90));
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
      if (await _finishIfDone(job)) {
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
        length: 'city',
        error: 'Сборка слишком долгая, попробуйте ещё раз',
      );
    });
  }

  Widget _body() {
    if (_job != null && (_job!.isActive || _job!.isError)) {
      return _generating(_search.text.trim());
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _cities.isEmpty) {
      final query = _search.text.trim();
      if (query.isNotEmpty && !_offline) {
        return _emptyGenerate(query);
      }
      return Center(
        child: TextButton(
          onPressed: _loadCatalog,
          child: Text('Не удалось загрузить каталог.\n$_error'),
        ),
      );
    }
    if (_cities.isEmpty) {
      final query = _search.text.trim();
      if (query.isEmpty || _offline) {
        return const Center(child: Text('По этому месту города пока нет'));
      }
      return _emptyGenerate(query);
    }
    final cities = _sorted(_cities);
    return ListView.separated(
      itemCount: cities.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = cities[index];
        return ListTile(
          leading: const Icon(Icons.location_city_outlined),
          title: Text(item.title),
          subtitle: Text(
            [
              if (item.subtitle != null) item.subtitle,
              if (item.region != null) item.region,
            ].whereType<String>().join('\n'),
          ),
          isThreeLine: item.subtitle != null && item.region != null,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openCity(item),
        );
      },
    );
  }
}

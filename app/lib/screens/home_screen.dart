import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../api/client.dart';
import '../maps/city_map.dart';
import '../maps/user_location.dart';
import '../models/city.dart';
import '../models/generate_job.dart';
import '../models/guide.dart';
import '../offline/guide_cache.dart';
import '../update/app_release.dart';
import '../update/app_updater.dart';
import '../update/update_banner.dart';
import 'city_tabs.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.api});

  final GuideApi api;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _search = TextEditingController();
  final _speech = SpeechToText();
  final _distance = const Distance();
  late final TabController _tabs;
  List<CitySummary> _cities = [];
  List<CitySummary> _catalog = [];
  List<GuideSummary> _guides = [];
  City? _city;
  String? _selectedPlaceId;
  bool _loading = true;
  String? _error;
  bool _offline = false;
  bool _listening = false;
  bool _userPicked = false;
  AppRelease? _update;
  GenerateJob? _job;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 7, vsync: this);
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
    if (!mounted || _userPicked || _search.text.trim().isNotEmpty) {
      return;
    }
    _selectNearest();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cities = await widget.api.listCities();
      List<GuideSummary> guides = [];
      try {
        guides = await widget.api.listGuides();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _cities = cities;
        _catalog = cities;
        _guides = guides;
        _loading = false;
        _offline = false;
      });
      await _selectNearest();
    } catch (error) {
      final local = await GuideCache.instance.localCities();
      final localGuides = await GuideCache.instance.localCatalog();
      if (!mounted) return;
      if (local.isNotEmpty) {
        setState(() {
          _cities = local;
          _catalog = local;
          _guides = localGuides;
          _loading = false;
          _offline = true;
          _error = null;
        });
        await _selectNearest();
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
      _userPicked = needle.isNotEmpty;
    });
    try {
      final cities = needle.isEmpty
          ? await widget.api.listCities()
          : await widget.api.searchCities(needle);
      if (!mounted) return;
      setState(() {
        _cities = cities;
        if (needle.isEmpty) {
          _catalog = cities;
          _userPicked = false;
        }
        _loading = false;
        _offline = false;
      });
      if (needle.isEmpty) {
        await _selectNearest();
        return;
      }
      if (cities.length == 1) {
        await _openCity(cities.first.id);
        return;
      }
      setState(() => _city = null);
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
        if (filtered.length == 1) {
          await _openCity(filtered.first.id);
        } else {
          setState(() => _city = null);
        }
        return;
      }
      setState(() {
        _cities = [];
        _city = null;
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _selectNearest() async {
    if (_userPicked || _catalog.isEmpty) {
      return;
    }
    final user = UserLocation.instance.fix;
    CitySummary pick = _catalog.first;
    if (user != null) {
      var best = double.infinity;
      for (final city in _catalog) {
        final meters = _distance.as(
          LengthUnit.Meter,
          LatLng(user.lat, user.lon),
          LatLng(city.center.lat, city.center.lon),
        );
        if (meters < best) {
          best = meters;
          pick = city;
        }
      }
    }
    if (_city?.id == pick.id) {
      return;
    }
    await _openCity(pick.id);
  }

  Future<void> _openCity(String id) async {
    try {
      final city = await widget.api.getCity(id);
      await GuideCache.instance.saveCity(city);
      if (!mounted) return;
      setState(() {
        _city = city;
        _selectedPlaceId = null;
        _error = null;
        _loading = false;
      });
      if (_tabs.index != 0) {
        _tabs.index = 0;
      }
    } catch (_) {
      final local = await GuideCache.instance.loadLocalCity(id);
      if (!mounted) return;
      if (local != null) {
        setState(() {
          _city = local;
          _selectedPlaceId = null;
          _offline = true;
          _loading = false;
        });
        return;
      }
      setState(() {
        _city = null;
        _error = 'Не удалось загрузить город';
        _loading = false;
      });
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
      localeId: 'ru_RU',
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
    _tabs.dispose();
    super.dispose();
  }

  void _onPlaceTap(CityPlace place) {
    var index = 2;
    if (place.group == PlaceGroup.guide) {
      index = city.guides.short != null ? 5 : 6;
    } else if (place.group == PlaceGroup.food) {
      index = 4;
    } else if (_city!.culture.any((item) => item.id == place.id)) {
      index = 3;
    }
    setState(() => _selectedPlaceId = place.id);
    _tabs.animateTo(index);
  }

  City get city => _city!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_city?.title ?? 'Город'),
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
        ],
      ),
      body: Column(
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
                child: Text('Нет сети — показан сохранённый город'),
              ),
            ),
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
                  : 'Собираю ${job.lengthLabel} «$query»',
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
    if (cityId != null && cityId.isNotEmpty) {
      if (mounted) {
        setState(() => _job = null);
      }
      await _loadCatalog();
      if (!mounted) {
        return true;
      }
      await _openCity(cityId);
      return true;
    }
    if (job.guideId != null) {
      if (mounted) {
        setState(() => _job = null);
      }
      await _loadCatalog();
      return true;
    }
    return false;
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

  Widget _cityList() {
    return ListView.separated(
      itemCount: _cities.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _cities[index];
        return ListTile(
          leading: const Icon(Icons.location_city),
          title: Text(item.title),
          subtitle: Text(
            [
              if (item.subtitle != null) item.subtitle,
              if (item.region != null) item.region,
            ].whereType<String>().join('\n'),
          ),
          isThreeLine: item.subtitle != null && item.region != null,
          onTap: () {
            _userPicked = true;
            _openCity(item.id);
          },
        );
      },
    );
  }

  Widget _body() {
    if (_job != null && (_job!.isActive || _job!.isError)) {
      return _generating(_search.text.trim());
    }
    if (_loading && _city == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_city != null) {
      return Column(
        children: [
          SizedBox(
            height: 240,
            child: CityMap(
              city: _city!,
              selectedId: _selectedPlaceId,
              onPlaceTap: _onPlaceTap,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: CityTabs(
              city: _city!,
              controller: _tabs,
              api: widget.api,
              guides: _guides,
              offline: _offline,
              selectedPlaceId: _selectedPlaceId,
              onGenerate: () => _startGenerate(_city!.city),
            ),
          ),
        ],
      );
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
    return _cityList();
  }
}

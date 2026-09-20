import 'package:flutter/material.dart';

import '../api/client.dart';
import '../maps/city_map.dart';
import '../models/city.dart';
import '../models/generate_job.dart';
import '../models/guide.dart';
import '../offline/guide_cache.dart';
import 'city_tabs.dart';

class CityScreen extends StatefulWidget {
  const CityScreen({
    super.key,
    required this.api,
    required this.cityId,
    this.guides = const [],
  });

  final GuideApi api;
  final String cityId;
  final List<GuideSummary> guides;

  @override
  State<CityScreen> createState() => _CityScreenState();
}

class _CityScreenState extends State<CityScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  City? _city;
  String? _selectedPlaceId;
  bool _loading = true;
  bool _offline = false;
  String? _error;
  GenerateJob? _job;
  List<GuideSummary> _guides = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 7, vsync: this);
    _guides = widget.guides;
    GuideCache.instance.addListener(_onCache);
    _open();
  }

  void _onCache() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _open() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final city = await widget.api.getCity(widget.cityId);
      await GuideCache.instance.saveCity(city);
      if (_guides.isEmpty) {
        try {
          _guides = await widget.api.listGuides();
        } catch (_) {
          _guides = await GuideCache.instance.localCatalog();
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _city = city;
        _loading = false;
        _offline = false;
      });
    } catch (_) {
      final local = await GuideCache.instance.loadLocalCity(widget.cityId);
      if (!mounted) {
        return;
      }
      if (local != null) {
        setState(() {
          _city = local;
          _loading = false;
          _offline = true;
        });
        return;
      }
      setState(() {
        _error = 'Не удалось загрузить город';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    GuideCache.instance.removeListener(_onCache);
    _tabs.dispose();
    super.dispose();
  }

  void _onPlaceTap(CityPlace place) {
    final city = _city;
    if (city == null) {
      return;
    }
    var index = 2;
    if (place.group == PlaceGroup.guide) {
      index = city.guides.short != null ? 5 : 6;
    } else if (place.group == PlaceGroup.food) {
      index = 4;
    } else if (city.culture.any((item) => item.id == place.id)) {
      index = 3;
    }
    setState(() => _selectedPlaceId = place.id);
    _tabs.animateTo(index);
  }

  Future<void> _startGenerate() async {
    final name = _city?.city ?? widget.cityId;
    setState(() => _job = null);
    try {
      final job = await widget.api.startCityGenerate(name);
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
          city: name,
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
    if (mounted) {
      setState(() => _job = null);
    }
    await _open();
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
        city: _city?.city ?? widget.cityId,
        status: 'error',
        step: 'Ошибка',
        length: 'city',
        error: 'Сборка слишком долгая, попробуйте ещё раз',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final city = _city;
    return Scaffold(
      appBar: AppBar(
        title: Text(city?.title ?? 'Город'),
      ),
      body: _body(city),
    );
  }

  Widget _body(City? city) {
    final job = _job;
    if (job != null && (job.isActive || job.isError)) {
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
                    : 'Собираю город',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(job.step, textAlign: TextAlign.center),
              if (job.isError) ...[
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _startGenerate,
                  child: const Text('Повторить'),
                ),
              ],
            ],
          ),
        ),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (city == null) {
      return Center(
        child: TextButton(
          onPressed: _open,
          child: Text(_error ?? 'Город не найден'),
        ),
      );
    }
    return Column(
      children: [
        if (_offline)
          const Material(
            color: Color(0xFFE8E4DC),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text('Нет сети — показан сохранённый город'),
            ),
          ),
        SizedBox(
          height: 240,
          child: CityMap(
            city: city,
            selectedId: _selectedPlaceId,
            onPlaceTap: _onPlaceTap,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: CityTabs(
            city: city,
            controller: _tabs,
            api: widget.api,
            guides: _guides,
            offline: _offline,
            selectedPlaceId: _selectedPlaceId,
            onGenerate: _startGenerate,
          ),
        ),
      ],
    );
  }
}

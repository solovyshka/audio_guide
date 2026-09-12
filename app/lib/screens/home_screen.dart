import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../api/client.dart';
import '../models/guide.dart';
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
  bool _listening = false;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
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
      });
    } catch (error) {
      if (!mounted) return;
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
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
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
        return ListTile(
          title: Text(guide.title),
          subtitle: Text(
            [
              if (guide.subtitle != null) guide.subtitle,
              '${guide.stopsCount} точек · $minutes мин',
            ].whereType<String>().join('\n'),
          ),
          isThreeLine: guide.subtitle != null,
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

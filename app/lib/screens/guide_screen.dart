import 'package:flutter/material.dart';

import '../api/client.dart';
import '../audio/guide_player.dart';
import '../config.dart';
import '../maps/available.dart';
import '../maps/yandex_view.dart';
import '../models/guide.dart';

class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key, required this.api, required this.guideId});

  final GuideApi api;
  final String guideId;

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  final _player = GuidePlayer();
  Guide? _guide;
  String? _error;

  bool get _useMap => yandexMapsSupported && mapkitApiKey.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final guide = await widget.api.getGuide(widget.guideId);
      await _player.load(guide);
      if (!mounted) return;
      setState(() => _guide = guide);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _playIndex(int index) async {
    await _player.playIndex(index);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error!)),
      );
    }
    final guide = _guide;
    if (guide == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text(guide.title)),
      body: Column(
        children: [
          Expanded(
            child: _useMap
                ? GuideYandexMap(
                    guide: guide,
                    onStopTap: (index) {
                      _playIndex(index);
                    },
                  )
                : _StopList(
                    guide: guide,
                    currentIndex: _player.index,
                    onTap: _playIndex,
                  ),
          ),
          _PlayerBar(
            player: _player,
            onChanged: () => setState(() {}),
          ),
        ],
      ),
    );
  }
}

class _StopList extends StatelessWidget {
  const _StopList({
    required this.guide,
    required this.currentIndex,
    required this.onTap,
  });

  final Guide guide;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final items = guide.playlist;
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final track = items[index];
        final selected = index == currentIndex;
        return ListTile(
          selected: selected,
          leading: CircleAvatar(child: Text('$index')),
          title: Text(track.title),
          subtitle: Text('${track.durationSec} сек'),
          onTap: () => onTap(index),
        );
      },
    );
  }
}

class _PlayerBar extends StatelessWidget {
  const _PlayerBar({required this.player, required this.onChanged});

  final GuidePlayer player;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final current = player.current;
    return Material(
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              current?.title ?? 'Выберите точку',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () async {
                    await player.previous();
                    onChanged();
                  },
                  icon: const Icon(Icons.skip_previous),
                ),
                IconButton(
                  iconSize: 40,
                  onPressed: () async {
                    await player.toggle();
                    onChanged();
                  },
                  icon: Icon(
                    player.playing ? Icons.pause_circle : Icons.play_circle,
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    await player.next();
                    onChanged();
                  },
                  icon: const Icon(Icons.skip_next),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

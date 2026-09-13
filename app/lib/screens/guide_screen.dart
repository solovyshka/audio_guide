import 'package:flutter/material.dart';

import '../api/client.dart';
import '../audio/guide_player.dart';
import '../config.dart';
import '../maps/available.dart';
import '../maps/yandex_view.dart';
import '../models/guide.dart';
import '../offline/guide_actions.dart';
import '../offline/guide_cache.dart';

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
      Guide? guide;
      try {
        guide = await widget.api.getGuide(widget.guideId);
        guide = await GuideCache.instance.withLocalAudio(guide);
      } catch (_) {
        guide = await GuideCache.instance.loadLocal(widget.guideId);
      }
      if (guide == null) {
        throw Exception('Гид не найден');
      }
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

    final list = _StopList(
      guide: guide,
      currentIndex: _player.index,
      onTap: _playIndex,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(guide.title),
        actions: [
          PopupMenuButton<GuideMenuAction>(
            tooltip: 'Ещё',
            onSelected: (action) async {
              await handleGuideMenu(
                context: context,
                api: widget.api,
                guide: guide,
                action: action,
                loaded: guide,
              );
              if (!mounted) {
                return;
              }
              if (action == GuideMenuAction.download ||
                  action == GuideMenuAction.delete) {
                await _open();
              }
            },
            itemBuilder: (_) => buildGuideMenuItems(guide),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_useMap)
            Expanded(
              flex: 1,
              child: ClipRect(
                child: GuideYandexMap(
                  guide: guide,
                  currentIndex: _player.index,
                  onStopTap: _playIndex,
                ),
              ),
            ),
          if (_useMap) const Divider(height: 1),
          Expanded(
            flex: 1,
            child: list,
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
          selectedTileColor: const Color(0x1F1F4B3A),
          leading: CircleAvatar(
            backgroundColor: selected
                ? const Color(0xFF1F4B3A)
                : const Color(0xFFE8E4DC),
            foregroundColor: selected
                ? Colors.white
                : const Color(0xFF1F4B3A),
            child: Text(index == 0 ? 'i' : '$index'),
          ),
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

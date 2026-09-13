import 'package:just_audio/just_audio.dart';

import '../models/guide.dart';

class GuidePlayer {
  GuidePlayer();

  final AudioPlayer _player = AudioPlayer();
  List<Track> _playlist = [];
  int index = 0;

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  bool get playing => _player.playing;
  Track? get current =>
      _playlist.isEmpty ? null : _playlist[index.clamp(0, _playlist.length - 1)];

  Future<void> load(Guide guide) async {
    _playlist = guide.playlist.where((track) => track.audioUrl != null).toList();
    index = 0;
    if (_playlist.isEmpty) {
      return;
    }
    await _setSource(_playlist.first.audioUrl!);
  }

  Future<void> playIndex(int nextIndex) async {
    if (nextIndex < 0 || nextIndex >= _playlist.length) {
      return;
    }
    index = nextIndex;
    await _setSource(_playlist[index].audioUrl!);
    await _player.play();
  }

  Future<void> _setSource(String source) async {
    if (source.startsWith('http://') || source.startsWith('https://')) {
      await _player.setUrl(source);
    } else {
      await _player.setFilePath(source);
    }
  }

  Future<void> toggle() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> next() => playIndex(index + 1);

  Future<void> previous() => playIndex(index - 1);

  Future<void> dispose() => _player.dispose();
}

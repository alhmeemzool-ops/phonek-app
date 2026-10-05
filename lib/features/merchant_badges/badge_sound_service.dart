import 'package:audioplayers/audioplayers.dart';

class BadgeSoundService {
  BadgeSoundService._();

  static final BadgeSoundService instance = BadgeSoundService._();
  AudioPlayer? _player;

  static const _names = <String>[
    'copper', 'bronze', 'iron', 'silver', 'gold',
    'platinum', 'emerald', 'ruby', 'sapphire', 'diamond',
  ];

  Future<void> playForLevel(int level) async {
    final safeLevel = level.clamp(1, 10);
    final filename = 'badge_level_' +
        safeLevel.toString().padLeft(2, '0') +
        '_' +
        _names[safeLevel - 1] +
        '.mp3';

    final previous = _player;
    _player = null;
    if (previous != null) {
      await previous.stop();
      await previous.dispose();
    }

    final player = AudioPlayer();
    _player = player;
    player.onPlayerComplete.listen((_) async {
      if (identical(_player, player)) {
        _player = null;
        await player.dispose();
      }
    });

    try {
      await player.play(
        AssetSource('badges/' + filename),
        mode: PlayerMode.mediaPlayer,
        ctx: AudioContext(
          android: AudioContextAndroid(
            usageType: AndroidUsageType.media,
            contentType: AndroidContentType.music,
            audioFocus: AndroidAudioFocus.gainTransient,
          ),
        ),
      );
    } catch (_) {
      if (identical(_player, player)) {
        _player = null;
      }
      await player.dispose();
      rethrow;
    }
  }

  Future<void> dispose() async {
    final player = _player;
    _player = null;
    if (player != null) {
      await player.stop();
      await player.dispose();
    }
  }
}
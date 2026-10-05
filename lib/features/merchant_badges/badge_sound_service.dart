import 'package:audioplayers/audioplayers.dart';

class BadgeSoundService {
  BadgeSoundService._();

  static AudioPlayer? _player;

  static const _names = <String>[
    'copper', 'bronze', 'iron', 'silver', 'gold',
    'platinum', 'emerald', 'ruby', 'sapphire', 'diamond',
  ];

  static Future<void> playForLevel(int level) async {
    final safeLevel = level.clamp(1, 10);
    final name = _names[safeLevel - 1];
    final filename = 'badge_level_' +
        safeLevel.toString().padLeft(2, '0') + '_' + name + '.mp3';

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
}
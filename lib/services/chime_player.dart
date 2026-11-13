import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

/// F-05: OVER 동안 차임 루프, NORMAL 복귀 즉시 정지.
/// 내비 안내·음악과 섞여 재생(iOS mixWithOthers + duckOthers,
/// Android usage=assistanceNavigationGuidance + transient may-duck focus).
class ChimePlayer {
  ChimePlayer({AudioPlayer? player})
    : _player = player ?? AudioPlayer(handleInterruptions: false);

  static const assetPath = 'assets/audio/chime.wav';

  final AudioPlayer _player;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    final session = await AudioSession.instance;
    await session.configure(
      AudioSessionConfiguration(
        // playback: iOS 무음 스위치에서도 재생
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.mixWithOthers |
            AVAudioSessionCategoryOptions.duckOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        androidAudioAttributes: const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.sonification,
          usage: AndroidAudioUsage.assistanceNavigationGuidance,
        ),
        androidAudioFocusGainType:
            AndroidAudioFocusGainType.gainTransientMayDuck,
        androidWillPauseWhenDucked: false,
      ),
    );
    await _player.setAsset(assetPath);
    await _player.setLoopMode(LoopMode.one);
    _ready = true;
  }

  Future<void> setVolume(double v) => _player.setVolume(v.clamp(0.0, 1.0));

  Future<void> start() async {
    await init();
    if (_player.playing) return;
    await _player.seek(Duration.zero);
    await (await AudioSession.instance).setActive(true);
    // play() completes only when playback stops, so don't await it.
    _player.play();
  }

  Future<void> stop() async {
    if (!_player.playing) return;
    await _player.pause();
    await _player.seek(Duration.zero);
  }

  /// F-08 미리듣기: 한 주기만 재생.
  Future<void> preview() async {
    await init();
    await _player.setLoopMode(LoopMode.off);
    await _player.seek(Duration.zero);
    await _player.play();
    await _player.setLoopMode(LoopMode.one);
  }

  Future<void> dispose() => _player.dispose();
}

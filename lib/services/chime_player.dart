import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../core/chime_sound.dart';

/// F-05: OVER 동안 차임 루프, NORMAL 복귀 즉시 정지.
/// 내비 안내·음악과 섞여 재생(iOS mixWithOthers + duckOthers,
/// Android usage=assistanceNavigationGuidance + transient may-duck focus).
class ChimePlayer {
  ChimePlayer({AudioPlayer? player, AudioPlayer? previewPlayer})
    : _player = player ?? AudioPlayer(handleInterruptions: false),
      _preview = previewPlayer ?? AudioPlayer(handleInterruptions: false);

  static const assetPath = 'assets/audio/chime.wav';

  /// 경고 루프에 지금 걸린 소리, 미리듣기 플레이어에 걸린 소리.
  ChimeSound _alertSound = ChimeCatalog.defaultSound;
  ChimeSound _previewSound = ChimeCatalog.defaultSound;

  /// 경고용 루프 플레이어 (상태 머신 chimeOn 만 제어).
  final AudioPlayer _player;

  /// 미리듣기 전용 1회 재생 플레이어. 경고 루프와 상태를 공유하지 않는다.
  final AudioPlayer _preview;
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
    await _preview.setAsset(assetPath);
    await _preview.setLoopMode(LoopMode.off);
    _ready = true;
  }

  Future<void> setVolume(double v) async {
    final vol = v.clamp(0.0, 1.0);
    await _player.setVolume(vol);
    await _preview.setVolume(vol);
  }

  ChimeSound get alertSound => _alertSound;

  /// 경고음 선택. 내 사운드를 못 불러오면 기본음으로 되돌리고 false.
  Future<bool> useSound(ChimeSound sound) async {
    await init();
    if (sound == _alertSound) return true;
    final wasPlaying = _player.playing;
    if (wasPlaying) await _player.pause();
    var ok = true;
    try {
      await _load(_player, sound);
      _alertSound = sound;
    } catch (_) {
      ok = false;
      await _load(_player, ChimeCatalog.defaultSound);
      _alertSound = ChimeCatalog.defaultSound;
    }
    await _player.setLoopMode(LoopMode.one);
    if (wasPlaying) _player.play();
    return ok;
  }

  /// 파일을 실제로 열어 길이를 잰다 (내 사운드 검사용). 못 열면 null.
  Future<Duration?> probe(String filePath) async {
    final p = AudioPlayer(handleInterruptions: false);
    try {
      return await p.setFilePath(filePath);
    } catch (_) {
      return null;
    } finally {
      await p.dispose();
    }
  }

  static Future<Duration?> _load(AudioPlayer p, ChimeSound s) => switch (s) {
    AssetChimeSound(:final assetPath) => p.setAsset(assetPath),
    CustomChimeSound(:final filePath) => p.setFilePath(filePath),
  };

  Future<void> start() async {
    await init();
    await stopPreview();
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

  /// F-08 미리듣기: [sound](없으면 지금 경고음)를 1회만 재생.
  /// 경고 루프가 울리는 중이면 무시. 못 불러오면 false.
  Future<bool> preview([ChimeSound? sound]) async {
    await init();
    if (_player.playing) return true;
    await _preview.pause();
    final target = sound ?? _alertSound;
    if (target != _previewSound) {
      try {
        await _load(_preview, target);
        _previewSound = target;
      } catch (_) {
        return false;
      }
    }
    await _preview.seek(Duration.zero);
    await (await AudioSession.instance).setActive(true);
    // play() completes only when playback stops, so don't await it.
    _preview.play();
    return true;
  }

  /// 미리듣기 중단 (설정 화면을 떠날 때 등).
  Future<void> stopPreview() async {
    if (!_preview.playing) return;
    await _preview.pause();
    await _preview.seek(Duration.zero);
  }

  Future<void> dispose() async {
    await _preview.dispose();
    await _player.dispose();
  }
}

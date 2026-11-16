import 'package:flutter_test/flutter_test.dart';
import 'package:speedchime/core/chime_sound.dart';

void main() {
  group('ChimeCatalog.fromAssets', () {
    test('이름 붙은 기본음이 먼저, 폴더에 추가한 파일은 이름순으로 뒤에', () {
      final c = ChimeCatalog.fromAssets([
        'assets/audio/zz_horn.mp3',
        'assets/audio/chime_soft.wav',
        'assets/audio/chime.wav',
        'assets/audio/engine_bell-2.ogg',
        'assets/audio/chime_beep.wav',
        'assets/audio/chime_triple.wav',
      ]);
      expect(c.builtIns.map((s) => s.label), [
        '기본 띵똥',
        '트리플 벨',
        '부드러운 차임',
        '디지털 삐삐',
        'engine bell 2',
        'zz horn',
      ]);
    });

    test('오디오가 아닌 파일, 하위 폴더, 다른 폴더는 제외', () {
      final c = ChimeCatalog.fromAssets([
        'assets/audio/chime.wav',
        'assets/audio/readme.txt',
        'assets/audio/old/x.wav',
        'assets/images/y.wav',
        'assets/audio/.hidden',
      ]);
      expect(c.builtIns, [ChimeCatalog.defaultSound]);
    });

    test('목록을 못 읽어도 기본음은 남는다', () {
      expect(ChimeCatalog.fromAssets([]).builtIns, [ChimeCatalog.defaultSound]);
    });
  });

  group('resolve', () {
    final c = ChimeCatalog.fromAssets([
      'assets/audio/chime.wav',
      'assets/audio/chime_beep.wav',
    ]);

    test('저장된 기본음 id', () {
      expect(
        c.resolve(soundId: 'asset:assets/audio/chime_beep.wav').label,
        '디지털 삐삐',
      );
    });

    test('사라진 파일이면 기본음', () {
      expect(
        c.resolve(soundId: 'asset:assets/audio/gone.wav'),
        ChimeCatalog.defaultSound,
      );
    });

    test('내 사운드: 경로가 있으면 그 파일, 없으면 기본음', () {
      final s = c.resolve(
        soundId: 'custom',
        customPath: '/data/custom.mp3',
        customName: 'my horn.mp3',
      );
      expect(s, isA<CustomChimeSound>());
      expect(s.label, 'my horn.mp3');
      expect(c.resolve(soundId: 'custom'), ChimeCatalog.defaultSound);
    });
  });

  group('CustomSoundRules', () {
    test('형식·크기', () {
      expect(
        CustomSoundRules.check(fileName: 'a.MP3', sizeBytes: 1000),
        isNull,
      );
      expect(
        CustomSoundRules.check(fileName: 'a.flac', sizeBytes: 1000),
        contains('형식'),
      );
      expect(
        CustomSoundRules.check(fileName: 'noext', sizeBytes: 1),
        isNotNull,
      );
      expect(
        CustomSoundRules.check(fileName: 'a.wav', sizeBytes: 0),
        isNotNull,
      );
      expect(
        CustomSoundRules.check(
          fileName: 'a.wav',
          sizeBytes: CustomSoundRules.maxBytes + 1,
        ),
        contains('2MB'),
      );
    });

    test('길이', () {
      expect(
        CustomSoundRules.checkDuration(const Duration(seconds: 3)),
        isNull,
      );
      expect(
        CustomSoundRules.checkDuration(const Duration(seconds: 11)),
        contains('10초'),
      );
      expect(CustomSoundRules.checkDuration(null), isNotNull);
    });
  });
}

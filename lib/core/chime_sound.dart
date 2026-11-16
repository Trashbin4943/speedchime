/// 경고음 선택지.
///
/// - 기본 제공음: `assets/audio/` 의 파일. 아래 [ChimeCatalog.presets] 에 있는 것은
///   이름을 붙여 앞에 두고, 그 밖에 폴더에 넣은 오디오 파일도 자동으로 목록에 뜬다
///   (파일 이름이 표시 이름이 된다).
/// - 내 사운드: 사용자가 고른 파일을 앱 저장소에 복사해 쓴다.
sealed class ChimeSound {
  const ChimeSound();

  /// 설정에 저장되는 값.
  String get id;
  String get label;
}

class AssetChimeSound extends ChimeSound {
  const AssetChimeSound(this.assetPath, this.label);

  final String assetPath;
  @override
  final String label;

  @override
  String get id => 'asset:$assetPath';

  @override
  bool operator ==(Object other) =>
      other is AssetChimeSound && other.assetPath == assetPath;

  @override
  int get hashCode => assetPath.hashCode;
}

class CustomChimeSound extends ChimeSound {
  const CustomChimeSound(this.filePath, this.fileName);

  static const customId = 'custom';

  final String filePath;

  /// 사용자가 고른 원래 파일 이름 (표시용).
  final String fileName;

  @override
  String get id => customId;

  @override
  String get label => fileName;

  @override
  bool operator ==(Object other) =>
      other is CustomChimeSound && other.filePath == filePath;

  @override
  int get hashCode => filePath.hashCode;
}

/// 재생할 수 있는 오디오 확장자 (기본 제공·내 사운드 공통).
const audioExtensions = {'wav', 'mp3', 'm4a', 'aac', 'ogg'};

String? _extensionOf(String name) {
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return null;
  return name.substring(dot + 1).toLowerCase();
}

class ChimeCatalog {
  const ChimeCatalog(this.builtIns);

  static const folder = 'assets/audio/';
  static const defaultSound = AssetChimeSound('${folder}chime.wav', '기본 띵똥');

  /// 이름이 정해진 기본 제공음 (tool/gen_chime.py 로 합성). 이 순서로 보인다.
  static const presets = <AssetChimeSound>[
    defaultSound,
    AssetChimeSound('${folder}chime_triple.wav', '트리플 벨'),
    AssetChimeSound('${folder}chime_soft.wav', '부드러운 차임'),
    AssetChimeSound('${folder}chime_beep.wav', '디지털 삐삐'),
  ];

  /// 앱에 들어 있는 에셋 경로 목록으로 카탈로그를 만든다.
  /// 이름 붙은 기본음이 먼저, 폴더에 추가된 다른 오디오 파일은 이름순으로 뒤에.
  factory ChimeCatalog.fromAssets(Iterable<String> assetPaths) {
    final audio = {
      for (final a in assetPaths)
        if (a.startsWith(folder) &&
            !a.substring(folder.length).contains('/') &&
            audioExtensions.contains(_extensionOf(a)))
          a,
    };
    final named = [
      for (final p in presets)
        if (audio.contains(p.assetPath)) p,
    ];
    final extra = audio.difference({
      for (final p in named) p.assetPath,
    }).toList()..sort();
    return ChimeCatalog([
      // 기본음 파일은 항상 있다고 본다 (목록을 못 읽어도 하나는 남도록).
      if (named.isEmpty || named.first != defaultSound) defaultSound,
      ...named,
      for (final a in extra) AssetChimeSound(a, _labelFromFile(a)),
    ]);
  }

  static const fallback = ChimeCatalog([defaultSound]);

  final List<AssetChimeSound> builtIns;

  /// 저장된 선택을 실제 사운드로. 없어진 파일이면 기본음.
  ChimeSound resolve({
    required String soundId,
    String? customPath,
    String? customName,
  }) {
    if (soundId == CustomChimeSound.customId) {
      if (customPath != null && customPath.isNotEmpty) {
        return CustomChimeSound(customPath, customName ?? '내 사운드');
      }
      return defaultSound;
    }
    for (final s in builtIns) {
      if (s.id == soundId) return s;
    }
    return defaultSound;
  }

  /// `assets/audio/engine_bell-2.mp3` → `engine bell 2`
  static String _labelFromFile(String assetPath) {
    final file = assetPath.substring(assetPath.lastIndexOf('/') + 1);
    final stem = file.substring(0, file.lastIndexOf('.'));
    return stem.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
  }
}

/// 내 사운드로 받을 수 있는 파일인지 (재생 길이는 불러온 뒤 따로 확인).
abstract final class CustomSoundRules {
  static const maxBytes = 2 * 1024 * 1024;
  static const maxDuration = Duration(seconds: 10);

  /// 문제가 없으면 null, 있으면 사용자에게 보여줄 문구.
  static String? check({required String fileName, required int sizeBytes}) {
    final ext = _extensionOf(fileName);
    if (ext == null || !audioExtensions.contains(ext)) {
      return '지원하지 않는 형식입니다 (${audioExtensions.join('·')})';
    }
    if (sizeBytes <= 0) return '빈 파일입니다';
    if (sizeBytes > maxBytes) return '파일이 너무 큽니다 (2MB 이하)';
    return null;
  }

  static String? checkDuration(Duration? d) {
    if (d == null || d == Duration.zero) return '재생할 수 없는 파일입니다';
    if (d > maxDuration) return '너무 깁니다 (10초 이하)';
    return null;
  }

  static String extensionOf(String fileName) => _extensionOf(fileName) ?? '';
}

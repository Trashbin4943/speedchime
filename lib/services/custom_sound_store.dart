import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../core/chime_sound.dart';

/// 내 사운드를 받지 못한 이유 (사용자에게 그대로 보여줄 문구).
class CustomSoundException implements Exception {
  const CustomSoundException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// 고른 파일 (플랫폼 피커와 테스트를 잇는 최소 형태).
class PickedSound {
  const PickedSound({
    required this.name,
    required this.size,
    required this.readBytes,
  });

  final String name;
  final int size;
  final Future<Uint8List> Function() readBytes;
}

typedef SoundPicker = Future<PickedSound?> Function();
typedef DurationProbe = Future<Duration?> Function(String filePath);

/// 내 사운드: 사용자가 고른 파일을 앱 전용 폴더에 복사해 둔다.
/// 원본이 지워지거나 옮겨져도 경고음은 계속 울린다. 파일은 기기 밖으로 나가지 않는다.
class CustomSoundStore {
  CustomSoundStore({
    required this.probe,
    SoundPicker? picker,
    Future<Directory> Function()? baseDir,
  }) : _picker = picker ?? _platformPicker,
       _baseDir = baseDir ?? getApplicationSupportDirectory;

  /// 복사한 파일을 열어 재생 길이를 재는 함수 (못 열면 null).
  final DurationProbe probe;
  final SoundPicker _picker;
  final Future<Directory> Function() _baseDir;

  Future<Directory> _dir() async {
    final d = Directory('${(await _baseDir()).path}/custom_sound');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// 파일을 고르게 하고 받아들인다. 취소하면 null.
  Future<CustomChimeSound?> pickAndImport() async {
    final picked = await _picker();
    if (picked == null) return null;
    return import(picked);
  }

  Future<CustomChimeSound> import(PickedSound picked) async {
    final problem = CustomSoundRules.check(
      fileName: picked.name,
      sizeBytes: picked.size,
    );
    if (problem != null) throw CustomSoundException(problem);

    final dir = await _dir();
    final ext = CustomSoundRules.extensionOf(picked.name);
    // 같은 이름에 덮어쓰면 플레이어 캐시가 옛 파일을 쥐고 있을 수 있어 매번 새 이름.
    final file = File(
      '${dir.path}/custom_${DateTime.now().millisecondsSinceEpoch}.$ext',
    );
    await file.writeAsBytes(await picked.readBytes(), flush: true);

    final lengthProblem = CustomSoundRules.checkDuration(
      await probe(file.path),
    );
    if (lengthProblem != null) {
      await file.delete();
      throw CustomSoundException(lengthProblem);
    }
    await _removeAllExcept(dir, file.path);
    return CustomChimeSound(file.path, picked.name);
  }

  /// 내 사운드 파일 삭제.
  Future<void> remove() async {
    final dir = await _dir();
    await _removeAllExcept(dir, null);
  }

  static Future<void> _removeAllExcept(Directory dir, String? keep) async {
    await for (final e in dir.list()) {
      if (e is File && e.path != keep) await e.delete();
    }
  }

  static Future<PickedSound?> _platformPicker() async {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: audioExtensions.toList(),
    );
    if (f == null) return null;
    return PickedSound(
      name: f.name,
      size: f.lengthSync() ?? await f.length() ?? 0,
      readBytes: f.readAsBytes,
    );
  }
}

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:speedchime/services/custom_sound_store.dart';

void main() {
  late Directory tmp;
  Duration? probed;

  CustomSoundStore store({SoundPicker? picker}) => CustomSoundStore(
    probe: (_) async => probed,
    picker: picker,
    baseDir: () async => tmp,
  );

  PickedSound file(String name, [int size = 4]) => PickedSound(
    name: name,
    size: size,
    readBytes: () async => Uint8List.fromList(List.filled(size, 7)),
  );

  List<String> stored() =>
      Directory('${tmp.path}/custom_sound')
          .listSync()
          .map((e) => e.path)
          .toList();

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('custom_sound_test');
    probed = const Duration(seconds: 2);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('받아들이면 앱 폴더에 복사하고 원래 이름을 기억', () async {
    final s = await store().import(file('My Horn.mp3'));
    expect(s.fileName, 'My Horn.mp3');
    expect(File(s.filePath).existsSync(), isTrue);
    expect(s.filePath, startsWith('${tmp.path}/custom_sound/'));
    expect(s.filePath, endsWith('.mp3'));
  });

  test('새로 받으면 예전 파일은 지운다', () async {
    final a = await store().import(file('a.wav'));
    await Future<void>.delayed(const Duration(milliseconds: 2));
    final b = await store().import(file('b.wav'));
    expect(stored(), [b.filePath]);
    expect(File(a.filePath).existsSync(), isFalse);
  });

  test('형식이 틀리면 복사하지 않음', () async {
    await expectLater(
      store().import(file('song.flac')),
      throwsA(isA<CustomSoundException>()),
    );
    expect(Directory('${tmp.path}/custom_sound').existsSync(), isFalse);
  });

  test('너무 길거나 못 열면 복사본을 지우고 거절', () async {
    probed = const Duration(seconds: 30);
    await expectLater(
      store().import(file('long.mp3')),
      throwsA(
        isA<CustomSoundException>().having(
          (e) => e.message,
          'm',
          contains('10초'),
        ),
      ),
    );
    probed = null;
    await expectLater(
      store().import(file('broken.mp3')),
      throwsA(isA<CustomSoundException>()),
    );
    expect(stored(), isEmpty);
  });

  test('실패해도 기존 내 사운드는 남는다', () async {
    final ok = await store().import(file('ok.wav'));
    probed = const Duration(seconds: 30);
    await expectLater(store().import(file('long.wav')), throwsA(anything));
    expect(stored(), [ok.filePath]);
  });

  test('선택 취소 → null', () async {
    expect(await store(picker: () async => null).pickAndImport(), isNull);
  });

  test('삭제', () async {
    await store().import(file('a.wav'));
    await store().remove();
    expect(stored(), isEmpty);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:speedchime/core/relay_notification.dart';

void main() {
  test('On: 추적 중 문구 + 기준 속도, Off 버튼 하나', () {
    final c = RelayNotification.build(on: true, thresholdKph: 120);
    expect(c.title, 'Chime Relay On');
    expect(c.text, contains('120 km/h'));
    expect(c.buttons.map((b) => b.command), [RelayCommand.off]);
  });

  test('Off: 일시정지 문구, On·종료 버튼', () {
    final c = RelayNotification.build(on: false, thresholdKph: 140);
    expect(c.title, 'Chime Relay Off');
    expect(c.buttons.map((b) => b.command), [
      RelayCommand.on,
      RelayCommand.exit,
    ]);
  });

  test('버튼 id ↔ 명령 왕복', () {
    for (final cmd in RelayCommand.values) {
      expect(RelayCommand.fromId(cmd.id), cmd);
    }
    expect(RelayCommand.fromId('unknown'), isNull);
    expect(RelayCommand.fromId(null), isNull);
  });
}

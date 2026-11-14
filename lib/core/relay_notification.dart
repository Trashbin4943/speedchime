/// F-06: 상단 알림 "Chime Relay" 의 내용과 버튼.
///
/// Chime Relay On  = 속도 추적 + 차임 경고 동작 중.  버튼: [Off]
/// Chime Relay Off = 추적 일시정지(GPS·차임 꺼짐), 알림은 유지. 버튼: [On] [종료]
/// 종료             = 알림(Foreground Service)까지 닫음 → 대기 상태.
///
/// 플러그인 타입을 쓰지 않는 순수 Dart 라서 단위 테스트한다.
enum RelayCommand {
  on('relay_on'),
  off('relay_off'),
  exit('relay_exit');

  const RelayCommand(this.id);

  /// 알림 버튼 id 이자 TaskHandler → 메인 isolate 로 보내는 메시지.
  final String id;

  static RelayCommand? fromId(Object? id) {
    for (final c in values) {
      if (c.id == id) return c;
    }
    return null;
  }
}

class RelayButton {
  const RelayButton(this.command, this.label);

  final RelayCommand command;
  final String label;
}

class RelayNotificationContent {
  const RelayNotificationContent({
    required this.title,
    required this.text,
    required this.buttons,
  });

  final String title;
  final String text;
  final List<RelayButton> buttons;
}

abstract final class RelayNotification {
  static RelayNotificationContent build({
    required bool on,
    required int thresholdKph,
  }) {
    if (on) {
      return RelayNotificationContent(
        title: 'Chime Relay On',
        text: '속도 추적 중 · 기준 $thresholdKph km/h',
        buttons: const [RelayButton(RelayCommand.off, 'Off')],
      );
    }
    return const RelayNotificationContent(
      title: 'Chime Relay Off',
      text: '추적 일시정지 · On 을 누르면 다시 시작',
      buttons: [
        RelayButton(RelayCommand.on, 'On'),
        RelayButton(RelayCommand.exit, '종료'),
      ],
    );
  }
}

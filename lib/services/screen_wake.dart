import 'package:wakelock_plus/wakelock_plus.dart';

/// F-07 화면 켜짐 유지. 컨트롤러 테스트에서 대체할 수 있도록 감싼다.
class ScreenWake {
  Future<void> enable() => WakelockPlus.enable();
  Future<void> disable() => WakelockPlus.disable();
}

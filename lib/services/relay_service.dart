import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../core/relay_notification.dart';

/// F-06: Android location 타입 Foreground Service + 알림 버튼.
///
/// 속도 파이프라인은 메인 isolate(DriveController)에서 돈다. 이 서비스는
/// 프로세스를 포그라운드로 유지하고, 알림 버튼 입력을 메인 isolate 로 넘긴다.
/// 앱 태스크를 지우면(stopWithTask) 서비스도 같이 종료된다.
class RelayService {
  static const _serviceId = 86;

  final _commands = StreamController<RelayCommand>.broadcast();
  bool _initialized = false;

  /// 알림 버튼으로 들어온 명령.
  Stream<RelayCommand> get commands => _commands.stream;

  /// main() 에서 runApp 전에 한 번 호출.
  static void initCommunicationPort() =>
      FlutterForegroundTask.initCommunicationPort();

  void _init() {
    if (_initialized) return;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'chime_relay',
        channelName: 'Chime Relay',
        channelDescription: '속도 추적 상태와 On/Off 버튼을 표시합니다.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        allowWakeLock: true,
        // 파이프라인이 메인 isolate 에 있으므로, 앱 없이 서비스만 살아나면 안 된다.
        allowAutoRestart: false,
        stopWithTask: true,
      ),
    );
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
    _initialized = true;
  }

  void _onTaskData(Object data) {
    final cmd = RelayCommand.fromId(data);
    if (cmd != null) _commands.add(cmd);
  }

  Future<bool> get isRunning => FlutterForegroundTask.isRunningService;

  /// 서비스가 없으면 시작하고, 있으면 알림 내용만 갱신한다.
  Future<void> show({required bool on, required int thresholdKph}) async {
    _init();
    final c = RelayNotification.build(on: on, thresholdKph: thresholdKph);
    final buttons = [
      for (final b in c.buttons)
        NotificationButton(id: b.command.id, text: b.label),
    ];
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(
        notificationTitle: c.title,
        notificationText: c.text,
        notificationButtons: buttons,
      );
      return;
    }
    final result = await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: [ForegroundServiceTypes.location],
      notificationTitle: c.title,
      notificationText: c.text,
      notificationButtons: buttons,
      callback: relayTaskCallback,
    );
    if (result is ServiceRequestFailure) {
      throw StateError('Chime Relay 서비스 시작 실패: ${result.error}');
    }
  }

  Future<void> stop() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }
}

/// Foreground Service 엔진에서 실행되는 진입점. top-level 이어야 한다.
@pragma('vm:entry-point')
void relayTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_RelayTaskHandler());
}

/// 알림 버튼 입력만 메인 isolate 로 전달한다. 다른 일은 하지 않는다.
class _RelayTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  @override
  void onNotificationButtonPressed(String id) {
    FlutterForegroundTask.sendDataToMain(id);
  }
}

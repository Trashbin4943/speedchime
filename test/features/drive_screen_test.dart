import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:speedchime/core/alert_state_machine.dart';
import 'package:speedchime/core/app_settings.dart';
import 'package:speedchime/features/drive/drive_controller.dart';
import 'package:speedchime/features/drive/drive_screen.dart';
import 'package:speedchime/providers.dart';
import 'package:speedchime/ui/meter_theme.dart';

class _FixedDrive extends DriveController {
  _FixedDrive(this.fixed);
  final DriveState fixed;

  @override
  DriveState build() => fixed;
}

class _FakeSettings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
}

Future<void> _pump(WidgetTester tester, DriveState s, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        driveControllerProvider.overrideWith(() => _FixedDrive(s)),
        settingsProvider.overrideWith(_FakeSettings.new),
      ],
      child: MaterialApp(theme: meterTheme(), home: const DriveScreen()),
    ),
  );
  // 말·램프 애니메이션이 돌고 있어도 몇 프레임 진행.
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  final states = <String, DriveState>{
    '대기': const DriveState(),
    '추적·정상': const DriveState(alert: AlertState.normal(), speedKph: 96),
    '추적·OVER': DriveState(
      alert: const AlertState.over(),
      speedKph: 132,
      relayShown: true,
    ),
    '추적·GPS 없음': const DriveState(alert: AlertState.normal()),
    'Relay Off': const DriveState(relayShown: true, permissionDenied: true),
  };
  const sizes = {'390×844': Size(390, 844), '360×640': Size(360, 640)};

  for (final s in states.entries) {
    for (final z in sizes.entries) {
      testWidgets('${s.key} @ ${z.key}: 넘침 없이 그려짐', (tester) async {
        await _pump(tester, s.value, z.value);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('버튼 문구와 상태 램프', (tester) async {
    await _pump(
      tester,
      const DriveState(alert: AlertState.over(), speedKph: 132),
      const Size(390, 844),
    );
    expect(find.text('주행 종료'), findsOneWidget);
    expect(find.text('습보'), findsOneWidget);
    expect(find.bySemanticsLabel('시속 132 킬로미터'), findsOneWidget);
    expect(find.bySemanticsLabel('OVER 켜짐'), findsOneWidget);
  });

  testWidgets('Relay Off: 주행 재개 + 알림 닫기', (tester) async {
    await _pump(
      tester,
      const DriveState(relayShown: true),
      const Size(390, 844),
    );
    expect(find.text('주행 재개'), findsOneWidget);
    expect(find.text('알림 닫기'), findsOneWidget);
    expect(find.text('정지'), findsOneWidget);
  });
}

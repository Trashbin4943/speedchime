# SpeedChime

GPS 속도가 기준(100/120/140kph, 기본 120)을 넘으면 AE86식 "띵똥" 차임을 반복 재생하는
Flutter(Android·iOS) 앱. 서버 없음, 위치는 기기 안에서만 처리. 요구사항 원문 요약은 `docs/PRD.md`.

## 명령어

```bash
./scripts/setup_flutter.sh          # Flutter SDK 없으면 ~/flutter 에 설치 + pub get
flutter analyze                     # 정적 분석 (경고 0 유지)
flutter test                        # 단위 테스트
dart format lib test                # 포맷 (CI가 검사함)
python3 tool/gen_chime.py           # assets/audio/chime.wav 재합성
flutter run                         # 실기기/에뮬레이터 실행
```

## 구조 (PRD 6. 파이프라인)

```
RelayService (flutter_foreground_task, location FGS + 알림 버튼)  lib/services/relay_service.dart  F-06
LocationService (geolocator, 1s)                lib/services/location_service.dart
  → SpeedFilter (정확도 필터 + EMA + 3s stale)   lib/core/speed_filter.dart        F-01, F-02
  → AlertStateMachine (idle/NORMAL/OVER)         lib/core/alert_state_machine.dart F-04
  → ChimePlayer (just_audio loop + audio_session) lib/services/chime_player.dart    F-05
DriveController (Riverpod Notifier)이 위 파이프라인을 묶음  lib/features/drive/drive_controller.dart
```

- `lib/core/` 는 Flutter·플러그인 import 금지인 순수 Dart. 시간(`now`)을 인자로 받는다. 반드시 단위 테스트.
- 차임 on/off 는 **상태 머신 출력(`chimeOn`)만** 결정한다. UI 에서 직접 재생 금지(미리듣기 제외).
- UI 는 `driveControllerProvider` 를 구독만 한다. 화면이 꺼져도 경고 동작이 유지돼야 한다.
- F-06 알림 "Chime Relay": On(추적 중, [Off]) / Off(일시정지, [On][종료]). 문구·버튼은
  `lib/core/relay_notification.dart`. 알림 버튼은 TaskHandler → `sendDataToMain` → `DriveController`
  의 `start/pause/stop` 으로 들어온다(앱 버튼과 같은 경로). 파이프라인은 메인 isolate 에서 돌고
  서비스는 `stopWithTask`·`allowAutoRestart: false` 라 앱 태스크를 지우면 같이 종료된다.
- 주행 화면은 택시미터(VFD) 콘셉트: 검은 배경 + 발광색 글자·선. 발광색은 설정의 테마 색(하늘색 기본/빨간색/노란색),
  `MeterPalette`(ThemeExtension, `lib/ui/meter_theme.dart`) 로 전달. 위젯은 `MeterPalette.of(context)` 만 쓰고 색을 하드코딩하지 않는다.
  OVER 경고색은 테마마다 발광색과 확실히 구분되는 색(하늘↔주황, 빨강↔노랑, 노랑↔빨강).
  속도는 `SevenSegmentDisplay`(꺼진 칸이 비치는 7-세그먼트), 달리는 말은 `RunningHorse`.
  말 다리 주기 = 1.6초 × 40 ÷ (속도 + 40) (`lib/core/gait.dart`), 위상을 누적해 속도가 바뀌어도 끊기지 않음.
  "애니메이션 줄이기" 설정이면 말·OVER 깜빡임을 멈춘다.
- 기준 속도(F-03)는 주행 화면에서 고르고, 주행 중에도 바꿀 수 있다. 바꾸면 즉시 다시 판정하고 알림 문구도 갱신
  (OVER 진입은 여전히 2초 지속 규칙).
- 저장 데이터는 기준 속도·음량·화면 켜짐 유지·테마 색(+고지 확인 여부)뿐. 위치 기록 저장 금지.

## 규칙

- 상태 머신/필터 파라미터를 바꾸면 `test/core/` 테스트를 같이 갱신.
- Android: `ACCESS_BACKGROUND_LOCATION` 추가 금지 (Foreground Service 로 대체, PRD 4).
- iOS: `UIBackgroundModes` = location + audio. 오디오 세션은 mixWithOthers|duckOthers, playback.
- 사용자 대면 문구는 한국어. "참고용 속도 / 법적 속도계 아님" 고지 유지.
- 비목표(회원가입·서버·주행기록·OBD·단속카메라·커스텀 사운드/속도) 는 구현하지 않는다.

## 알려진 TODO

- F-06 실기기 검증: 알림 버튼 동작, 앱을 백그라운드에 둔 채 Off/On, iOS 는 알림을 길게 눌러야 버튼이 보임.
- iOS `Podfile` 은 macOS 에서 첫 `pod install` 시 생성됨. 생성 후 permission_handler 매크로
  (`PERMISSION_LOCATION_WHENINUSE=1`, `PERMISSION_NOTIFICATIONS=1`) 를 post_install 에 추가.
- 배터리 최적화 제외 안내 화면 (삼성 등), Fastlane 배포 설정 (M4).
- 실기기 검증: Android Mock Location / Xcode GPX (`test/fixtures/highway_130kph.gpx`).

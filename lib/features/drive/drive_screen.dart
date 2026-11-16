import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/alert_state_machine.dart';
import '../../core/app_settings.dart';
import '../../core/gait.dart';
import '../../core/seven_segment.dart';
import '../../providers.dart';
import '../../ui/meter_theme.dart';
import '../../ui/running_horse.dart';
import '../../ui/seven_segment_display.dart';
import '../settings/settings_screen.dart';
import 'drive_controller.dart';

/// F-07 주행 화면 — 2000년대 택시미터(VFD) 콘셉트.
/// 속도는 7-세그먼트 숫자로, 달리는 말은 속도에 따라 다리 빠르기가 달라진다.
/// 기준 속도(F-03)는 이 화면에서 고르며, 주행 중에도 바꿀 수 있다.
class DriveScreen extends ConsumerWidget {
  const DriveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MeterPalette.of(context);
    final drive = ref.watch(driveControllerProvider);
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(driveControllerProvider.notifier);
    final over = drive.alert.phase == AlertPhase.over;
    final gait = Gait.forSpeed(drive.running ? drive.speedKph : null);

    final speedDigits = !drive.running
        ? SevenSegment.blank()
        : drive.speedKph == null
        ? SevenSegment.dashes()
        : SevenSegment.number(drive.speedKph!.round());
    final speedLabel = !drive.running
        ? '대기 중'
        : drive.speedKph == null
        ? '속도 없음'
        : '시속 ${drive.speedKph!.round()} 킬로미터';

    return Scaffold(
      backgroundColor: MeterPalette.background,
      body: SafeArea(
        child: DefaultTextStyle.merge(
          style: TextStyle(color: p.glow),
          // 작은 화면에서는 스크롤, 큰 화면에서는 버튼을 바닥에 붙인다.
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                sliver: SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(
                        drive: drive,
                        onSettings: drive.running
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SettingsScreen(),
                                ),
                              ),
                      ),
                      const SizedBox(height: 16),
                      _MeterPanel(
                        gait: gait,
                        speedDigits: speedDigits,
                        speedLabel: speedLabel,
                        thresholdKph: settings.thresholdKph,
                        onThreshold: ref
                            .read(settingsProvider.notifier)
                            .setThreshold,
                        running: drive.running,
                        over: over,
                      ),
                      const SizedBox(height: 16),
                      _RelayPanel(
                        running: drive.running,
                        paused: drive.paused,
                        onOn: drive.running ? null : controller.start,
                        onOff: drive.running ? controller.pause : null,
                      ),
                      const Spacer(),
                      const SizedBox(height: 16),
                      if (drive.permissionDenied)
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: p.over,
                            minimumSize: const Size.fromHeight(44),
                          ),
                          onPressed: () => ref
                              .read(permissionServiceProvider)
                              .openSettings(),
                          child: const Text('위치 권한이 필요합니다 · 설정 열기'),
                        ),
                      // 알림의 Chime Relay On/Off/종료 버튼과 같은 동작이다.
                      SizedBox(
                        height: 64,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: p.glow,
                            side: BorderSide(color: p.glow, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: drive.running
                              ? controller.stop
                              : controller.start,
                          child: Text(
                            drive.running
                                ? '주행 종료'
                                : drive.paused
                                ? '주행 재개'
                                : '주행 시작',
                          ),
                        ),
                      ),
                      if (drive.paused)
                        TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: p.secondary,
                            minimumSize: const Size.fromHeight(44),
                          ),
                          onPressed: controller.stop,
                          child: const Text('알림 닫기'),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        '참고용 속도입니다 · 법적 속도계가 아닙니다',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: p.secondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.drive, required this.onSettings});

  final DriveState drive;
  final VoidCallback? onSettings;

  @override
  Widget build(BuildContext context) {
    final p = MeterPalette.of(context);
    final (label, lit) = !drive.running
        ? (drive.paused ? 'Chime Relay Off' : '대기', false)
        : drive.gpsOk
        ? ('GPS 수신 중', true)
        : ('GPS 없음', false);
    return Row(
      children: [
        _Dot(lit: lit),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 13, color: lit ? p.glow : p.secondary),
          ),
        ),
        Text(
          'SPEEDCHIME',
          style: meterMono.copyWith(fontSize: 15, letterSpacing: 4),
        ),
        const Expanded(child: SizedBox()),
        SizedBox.square(
          dimension: 44,
          child: IconButton(
            tooltip: '설정',
            onPressed: onSettings,
            color: p.glow,
            disabledColor: p.dim,
            style: IconButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: onSettings == null ? p.dimBorder : p.line,
                ),
              ),
            ),
            icon: const Icon(Icons.settings_outlined, size: 20),
          ),
        ),
      ],
    );
  }
}

class _MeterPanel extends StatelessWidget {
  const _MeterPanel({
    required this.gait,
    required this.speedDigits,
    required this.speedLabel,
    required this.thresholdKph,
    required this.onThreshold,
    required this.running,
    required this.over,
  });

  final Gait gait;
  final List<Set<Seg>> speedDigits;
  final String speedLabel;
  final int thresholdKph;
  final ValueChanged<int> onThreshold;
  final bool running;
  final bool over;

  @override
  Widget build(BuildContext context) {
    final p = MeterPalette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: MeterPalette.panel,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: RunningHorse(gait: gait, color: p.glow),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        gait.tier.label,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        gait.moving
                            ? 'STRIDE ${gait.strideSeconds.toStringAsFixed(2)}s'
                            : 'STRIDE --',
                        style: meterMono.copyWith(
                          fontSize: 13,
                          color: p.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SevenSegmentDisplay(
                  digits: speedDigits,
                  digitWidth: 70,
                  digitHeight: 124,
                  color: p.glow,
                  semanticsLabel: speedLabel,
                ),
                const SizedBox(width: 14),
                Text('km/h', style: meterMono.copyWith(fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, thickness: 1, color: p.divider),
          const SizedBox(height: 14),
          Row(
            children: [
              Text('기준', style: TextStyle(fontSize: 13, color: p.secondary)),
              const SizedBox(width: 10),
              SevenSegmentDisplay(
                digits: SevenSegment.number(thresholdKph),
                digitWidth: 22,
                digitHeight: 38,
                gap: 5,
                color: p.glow,
                semanticsLabel: '기준 시속 $thresholdKph 킬로미터',
              ),
              const SizedBox(width: 12),
              // 좁은 화면에서는 램프 묶음만 줄인다.
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      children: [
                        _Lamp(label: 'NORMAL', lit: running && !over),
                        const SizedBox(width: 8),
                        _Lamp(
                          label: 'OVER',
                          lit: over,
                          warning: true,
                          blink: over,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ThresholdPicker(selected: thresholdKph, onSelected: onThreshold),
        ],
      ),
    );
  }
}

/// F-03 기준 속도 선택. 주행 중에도 누를 수 있도록 큼직하게 둔다.
class _ThresholdPicker extends StatelessWidget {
  const _ThresholdPicker({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final p = MeterPalette.of(context);
    return Row(
      children: [
        for (final kph in AppSettings.thresholdOptions) ...[
          if (kph != AppSettings.thresholdOptions.first)
            const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              button: true,
              selected: kph == selected,
              label: '기준 속도 $kph',
              excludeSemantics: true,
              child: Material(
                color: kph == selected ? p.litFill : Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: kph == selected ? p.glow : p.dimBorder,
                  ),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: kph == selected ? null : () => onSelected(kph),
                  child: SizedBox(
                    height: 48,
                    child: Center(
                      child: Text(
                        '$kph',
                        style: meterMono.copyWith(
                          fontSize: 18,
                          color: kph == selected ? p.glow : p.secondary,
                          shadows: kph == selected
                              ? [Shadow(color: p.glow, blurRadius: 8)]
                              : const [],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RelayPanel extends StatelessWidget {
  const _RelayPanel({
    required this.running,
    required this.paused,
    required this.onOn,
    required this.onOff,
  });

  final bool running;
  final bool paused;
  final VoidCallback? onOn;
  final VoidCallback? onOff;

  @override
  Widget build(BuildContext context) {
    final p = MeterPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: p.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CHIME RELAY',
                  style: meterMono.copyWith(fontSize: 15, letterSpacing: 2),
                ),
                const SizedBox(height: 4),
                Text(
                  '상단 알림에서도 On / Off',
                  style: TextStyle(fontSize: 12, color: p.secondary),
                ),
              ],
            ),
          ),
          _Lamp(label: 'ON', lit: running, button: true, onPressed: onOn),
          const SizedBox(width: 6),
          _Lamp(label: 'OFF', lit: paused, button: true, onPressed: onOff),
        ],
      ),
    );
  }
}

/// 미터기 램프. [button] 이면 44px 이상 터치 영역의 버튼이 된다.
class _Lamp extends StatefulWidget {
  const _Lamp({
    required this.label,
    required this.lit,
    this.warning = false,
    this.blink = false,
    this.button = false,
    this.onPressed,
  });

  final String label;
  final bool lit;
  final bool warning;
  final bool blink;

  /// 꺼져 있어도(비활성) 버튼으로 읽혀야 하는 램프 (Chime Relay ON/OFF).
  final bool button;
  final VoidCallback? onPressed;

  @override
  State<_Lamp> createState() => _LampState();
}

class _LampState extends State<_Lamp> with SingleTickerProviderStateMixin {
  late final AnimationController _blink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBlink();
  }

  @override
  void didUpdateWidget(_Lamp old) {
    super.didUpdateWidget(old);
    _syncBlink();
  }

  void _syncBlink() {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.blink && !reduce) {
      if (!_blink.isAnimating) _blink.repeat();
    } else {
      _blink
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = MeterPalette.of(context);
    final color = widget.warning ? p.over : p.glow;
    final fg = widget.lit ? color : p.dim;
    final lamp = AnimatedBuilder(
      animation: _blink,
      builder: (context, child) => Opacity(
        // steps(1): 반 주기 꺼짐
        opacity: _blink.value >= 0.5 ? 0.25 : 1,
        child: child,
      ),
      child: Container(
        constraints: const BoxConstraints(minHeight: 32),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: widget.lit && !widget.warning ? p.litFill : null,
          border: Border.all(color: widget.lit ? color : p.dimBorder),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          widget.label,
          style: meterMono.copyWith(
            fontSize: 14,
            color: fg,
            shadows: widget.lit
                ? [Shadow(color: color, blurRadius: 8)]
                : const [],
          ),
        ),
      ),
    );

    if (!widget.button) {
      return Semantics(
        label: '${widget.label} ${widget.lit ? '켜짐' : '꺼짐'}',
        excludeSemantics: true,
        child: lamp,
      );
    }
    return Semantics(
      button: true,
      enabled: widget.onPressed != null,
      label: 'Chime Relay ${widget.label}',
      excludeSemantics: true,
      child: InkWell(
        onTap: widget.onPressed,
        borderRadius: BorderRadius.circular(6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Center(child: lamp),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.lit});

  final bool lit;

  @override
  Widget build(BuildContext context) {
    final p = MeterPalette.of(context);
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: lit ? p.glow : p.dim,
        boxShadow: lit ? [BoxShadow(color: p.glow, blurRadius: 6)] : null,
      ),
    );
  }
}

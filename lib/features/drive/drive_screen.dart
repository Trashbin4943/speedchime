import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/alert_state_machine.dart';
import '../../providers.dart';
import '../settings/settings_screen.dart';
import 'drive_controller.dart';

/// F-07: 현재 속도 크게, 기준 속도, GPS 상태.
class DriveScreen extends ConsumerWidget {
  const DriveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drive = ref.watch(driveControllerProvider);
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(driveControllerProvider.notifier);
    final theme = Theme.of(context);
    final over = drive.alert.phase == AlertPhase.over;

    return Scaffold(
      backgroundColor: over ? Colors.red.shade900 : null,
      appBar: AppBar(
        title: const Text('SpeedChime'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: drive.running
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _GpsBadge(running: drive.running, gpsOk: drive.gpsOk),
              const Spacer(),
              Text(
                drive.speedKph?.round().toString() ?? '--',
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: 120,
                  fontWeight: FontWeight.bold,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text('km/h', style: theme.textTheme.titleLarge),
              const SizedBox(height: 16),
              Text(
                '기준 ${settings.thresholdKph} km/h',
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              if (drive.permissionDenied)
                TextButton(
                  onPressed: () =>
                      ref.read(permissionServiceProvider).openSettings(),
                  child: const Text('위치 권한이 필요합니다 · 설정 열기'),
                ),
              SizedBox(
                width: double.infinity,
                height: 64,
                child: FilledButton(
                  onPressed: drive.running ? controller.stop : controller.start,
                  child: Text(
                    drive.running ? '주행 종료' : '주행 시작',
                    style: const TextStyle(fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '참고용 속도입니다. 법적 속도계가 아닙니다.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GpsBadge extends StatelessWidget {
  const _GpsBadge({required this.running, required this.gpsOk});

  final bool running;
  final bool gpsOk;

  @override
  Widget build(BuildContext context) {
    final (label, color) = !running
        ? ('대기', Colors.grey)
        : gpsOk
        ? ('GPS 수신 중', Colors.green)
        : ('GPS 없음', Colors.orange);
    return Chip(
      avatar: Icon(Icons.gps_fixed, color: color, size: 18),
      label: Text(label),
    );
  }
}

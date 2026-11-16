import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_settings.dart';
import '../../providers.dart';
import '../../services/chime_player.dart';
import '../../ui/meter_theme.dart';

/// 테마 색, F-07 화면 켜짐 유지, F-08 미리듣기·음량.
/// 기준 속도(F-03)는 주행 화면에서 고른다.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // dispose() 에서는 ref 를 쓸 수 없으므로 미리 잡아 둔다.
  late final ChimePlayer _chime;

  @override
  void initState() {
    super.initState();
    _chime = ref.read(chimePlayerProvider);
  }

  @override
  void dispose() {
    // 화면을 떠나면 미리듣기 정지 (경고 루프에는 영향 없음).
    _chime.stopPreview();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final chime = _chime;

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('테마 색'),
          const SizedBox(height: 8),
          SegmentedButton<MeterTheme>(
            showSelectedIcon: false,
            segments: [
              for (final t in MeterTheme.values)
                ButtonSegment(
                  value: t,
                  icon: Icon(
                    Icons.circle,
                    size: 14,
                    color: MeterPalette.forTheme(t).glow,
                  ),
                  label: Text(t.label),
                ),
            ],
            selected: {s.theme},
            onSelectionChanged: (v) => n.setTheme(v.first),
          ),
          const SizedBox(height: 24),
          const Text('차임 음량'),
          Slider(
            value: s.volume,
            onChanged: (v) {
              n.setVolume(v);
              chime.setVolume(v);
            },
          ),
          OutlinedButton.icon(
            icon: const Icon(Icons.play_arrow),
            label: const Text('차임 미리듣기'),
            onPressed: () async {
              await chime.setVolume(s.volume);
              await chime.preview();
            },
          ),
          const SizedBox(height: 24),
          SwitchListTile(
            title: const Text('주행 중 화면 켜짐 유지'),
            value: s.keepScreenOn,
            onChanged: n.setKeepScreenOn,
          ),
        ],
      ),
    );
  }
}

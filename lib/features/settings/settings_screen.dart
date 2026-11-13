import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_settings.dart';
import '../../providers.dart';

/// F-03 기준 속도, F-07 화면 켜짐 유지, F-08 미리듣기·음량.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final chime = ref.read(chimePlayerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('기준 속도'),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: [
              for (final kph in AppSettings.thresholdOptions)
                ButtonSegment(value: kph, label: Text('$kph')),
            ],
            selected: {s.thresholdKph},
            onSelectionChanged: (v) => n.setThreshold(v.first),
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

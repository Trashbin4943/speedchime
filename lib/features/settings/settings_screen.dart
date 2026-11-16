import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_settings.dart';
import '../../core/chime_sound.dart';
import '../../providers.dart';
import '../../services/chime_player.dart';
import '../../services/custom_sound_store.dart';
import '../../ui/meter_theme.dart';

/// 테마 색, 경고음 선택(기본 제공음 + 내 사운드), F-07 화면 켜짐 유지, F-08 미리듣기·음량.
/// 기준 속도(F-03)는 주행 화면에서 고른다.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // dispose() 에서는 ref 를 쓸 수 없으므로 미리 잡아 둔다.
  late final ChimePlayer _chime;
  bool _importing = false;

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

  Future<void> _preview(ChimeSound sound) async {
    await _chime.setVolume(ref.read(settingsProvider).volume);
    final ok = await _chime.preview(sound);
    if (!ok) _toast('이 소리를 재생할 수 없습니다');
  }

  Future<void> _importCustom() async {
    setState(() => _importing = true);
    try {
      final sound = await ref.read(customSoundStoreProvider).pickAndImport();
      if (sound == null) return; // 선택 취소
      await ref.read(settingsProvider.notifier).setCustomSound(sound);
      await _preview(sound);
    } on CustomSoundException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('파일을 불러오지 못했습니다');
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _removeCustom() async {
    await ref.read(customSoundStoreProvider).remove();
    await ref.read(settingsProvider.notifier).clearCustomSound();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
          const Text('경고음'),
          const SizedBox(height: 4),
          _SoundList(
            selected: ref.watch(selectedSoundProvider),
            catalog:
                ref.watch(chimeCatalogProvider).value ?? ChimeCatalog.fallback,
            custom: s.customSoundPath == null
                ? null
                : CustomChimeSound(
                    s.customSoundPath!,
                    s.customSoundName ?? '내 사운드',
                  ),
            importing: _importing,
            onSelect: n.setSound,
            onPreview: _preview,
            onImport: _importCustom,
            onRemove: _removeCustom,
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
            onPressed: () => _preview(ref.read(selectedSoundProvider)),
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

/// 경고음 목록: 기본 제공음(assets/audio) + 내 사운드. 각 줄에 미리듣기.
class _SoundList extends StatelessWidget {
  const _SoundList({
    required this.selected,
    required this.catalog,
    required this.custom,
    required this.importing,
    required this.onSelect,
    required this.onPreview,
    required this.onImport,
    required this.onRemove,
  });

  final ChimeSound selected;
  final ChimeCatalog catalog;
  final CustomChimeSound? custom;
  final bool importing;
  final ValueChanged<ChimeSound> onSelect;
  final ValueChanged<ChimeSound> onPreview;
  final VoidCallback onImport;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final p = MeterPalette.of(context);
    final options = <ChimeSound>[...catalog.builtIns, ?custom];

    Widget row(ChimeSound sound, {String? subtitle}) => RadioListTile<String>(
      value: sound.id,
      contentPadding: EdgeInsets.zero,
      title: Text(sound.label, overflow: TextOverflow.ellipsis),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, style: TextStyle(color: p.secondary)),
      secondary: IconButton(
        tooltip: '${sound.label} 미리듣기',
        icon: const Icon(Icons.play_arrow),
        onPressed: () => onPreview(sound),
      ),
    );

    return RadioGroup<String>(
      groupValue: selected.id,
      onChanged: (id) {
        for (final o in options) {
          if (o.id == id) return onSelect(o);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final b in catalog.builtIns) row(b),
          if (custom != null) ...[
            row(custom!, subtitle: '내 사운드'),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('다른 파일로 바꾸기'),
                  onPressed: importing ? null : onImport,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('내 사운드 삭제'),
                  onPressed: importing ? null : onRemove,
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 4),
            OutlinedButton.icon(
              icon: importing
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.library_music_outlined),
              label: const Text('내 사운드 추가'),
              onPressed: importing ? null : onImport,
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '${audioExtensions.join('·')} · 2MB·10초 이하 · 파일은 기기 안에만 저장됩니다',
            style: TextStyle(fontSize: 12, color: p.secondary),
          ),
        ],
      ),
    );
  }
}

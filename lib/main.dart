import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'features/drive/drive_screen.dart';
import 'features/onboarding/disclaimer_screen.dart';
import 'providers.dart';
import 'services/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repo = await SettingsRepository.create();
  runApp(
    ProviderScope(
      overrides: [settingsRepositoryProvider.overrideWithValue(repo)],
      child: SpeedChimeApp(showDisclaimer: !repo.disclaimerAccepted),
    ),
  );
}

class SpeedChimeApp extends ConsumerStatefulWidget {
  const SpeedChimeApp({super.key, required this.showDisclaimer});

  final bool showDisclaimer;

  @override
  ConsumerState<SpeedChimeApp> createState() => _SpeedChimeAppState();
}

class _SpeedChimeAppState extends ConsumerState<SpeedChimeApp> {
  late bool _showDisclaimer = widget.showDisclaimer;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpeedChime',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.dark,
        ),
      ),
      home: _showDisclaimer
          ? DisclaimerScreen(
              onAccept: () async {
                await ref.read(settingsRepositoryProvider).acceptDisclaimer();
                setState(() => _showDisclaimer = false);
              },
            )
          : const DriveScreen(),
    );
  }
}

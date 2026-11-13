import 'package:material_ui/material_ui.dart';

/// PRD 4. 안전: 첫 실행 화면에 "안전 운전 보조용, 법적 속도계 아님" 고지.
class DisclaimerScreen extends StatelessWidget {
  const DisclaimerScreen({super.key, required this.onAccept});

  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(),
              Text('SpeedChime', style: theme.textTheme.headlineLarge),
              const SizedBox(height: 16),
              const Text(
                '이 앱은 안전 운전 보조용이며 법적 속도계가 아닙니다.\n'
                'GPS로 측정한 속도는 참고용이며 계기판과 차이가 날 수 있습니다.\n\n'
                '주행 중에는 앱을 조작하지 마세요.\n\n'
                '위치 정보는 기기 안에서만 처리되며 저장하거나 전송하지 않습니다.',
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onAccept,
                  child: const Text('확인했습니다'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

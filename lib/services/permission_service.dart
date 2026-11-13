import 'package:permission_handler/permission_handler.dart';

/// PRD 4. 권한: 위치(앱 사용 중) + 알림.
/// Android 백그라운드 위치(ACCESS_BACKGROUND_LOCATION)는 요청하지 않고
/// Foreground Service로 대체한다.
class PermissionService {
  /// Returns true when location (when-in-use) is granted.
  Future<bool> ensureDrivingPermissions() async {
    final loc = await Permission.locationWhenInUse.request();
    // Android 13+ 알림 권한. 거부돼도 추적 자체는 가능하므로 결과는 무시.
    await Permission.notification.request();
    return loc.isGranted || loc.isLimited;
  }

  Future<bool> openSettings() => openAppSettings();
}

import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart';

import '../core/speed_filter.dart';

/// F-01 / F-06: 1초 간격 위치 스트림. Android는 location 타입
/// Foreground Service 알림으로, iOS는 Background Modes(location)로 백그라운드 유지.
///
/// TODO(F-06): 알림의 "종료" 액션 버튼은 geolocator 알림이 지원하지 않으므로
/// flutter_foreground_task 로 전환하거나 플랫폼 채널로 구현해야 한다.
class LocationService {
  Stream<RawFix> fixes() {
    return Geolocator.getPositionStream(locationSettings: _settings())
        .map(_toFix);
  }

  LocationSettings _settings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 0,
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'SpeedChime',
          notificationText: '속도 추적 중',
          enableWakeLock: true,
          setOngoing: true,
        ),
      );
    }
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: true,
        allowBackgroundLocationUpdates: true,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.best);
  }

  static RawFix _toFix(Position p) => RawFix(
    timestamp: p.timestamp,
    latitude: p.latitude,
    longitude: p.longitude,
    horizontalAccuracyM: p.accuracy,
    speedMps: p.speed,
    speedAccuracyMps: p.speedAccuracy,
  );
}

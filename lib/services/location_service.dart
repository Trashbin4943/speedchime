import 'dart:io' show Platform;

import 'package:geolocator/geolocator.dart';

import '../core/speed_filter.dart';

/// F-01: 1초 간격 위치 스트림.
/// 백그라운드 유지는 Android 에서는 RelayService(location 타입 Foreground
/// Service)가, iOS 에서는 Background Modes(location)가 맡는다. 그래서 여기서는
/// geolocator 자체 Foreground 알림을 쓰지 않는다(알림이 두 개 뜨는 것 방지).
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

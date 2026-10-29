import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../../map/services/location_service.dart';
import 'location_runtime_models.dart';

abstract class TripLocationDriver {
  Future<TripLocationCapability> capability({bool request = false});
  Future<TripLocationSample> current();
  Stream<TripLocationSample> backgroundPositions(Duration interval);
  Stream<bool> serviceChanges();
}

class GeolocatorTripLocationDriver implements TripLocationDriver {
  GeolocatorTripLocationDriver({GoMateLocationService? location})
    : _location = location ?? GoMateLocationService();
  final GoMateLocationService _location;
  @override
  Future<TripLocationCapability> capability({bool request = false}) async {
    final service = await geo.Geolocator.isLocationServiceEnabled();
    var permission = await geo.Geolocator.checkPermission();
    if (request && service && permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    return TripLocationCapability(
      serviceOn: service,
      foregroundAllowed:
          permission == geo.LocationPermission.whileInUse ||
          permission == geo.LocationPermission.always,
      backgroundAllowed: permission == geo.LocationPermission.always,
      android: !kIsWeb && defaultTargetPlatform == TargetPlatform.android,
    );
  }

  TripLocationSample _sample(geo.Position p) =>
      TripLocationSample(p.latitude, p.longitude, p.accuracy, p.timestamp);
  @override
  Future<TripLocationSample> current() async {
    final result = await _location
        .getCurrentLocation(requestPermission: false)
        .timeout(const Duration(seconds: 12));
    if (result.state != GoMateLocationState.ready || result.position == null) {
      throw StateError('Không lấy được vị trí hiện tại.');
    }
    return _sample(result.position!);
  }

  @override
  Stream<TripLocationSample> backgroundPositions(Duration interval) =>
      geo.Geolocator.getPositionStream(
        locationSettings: geo.AndroidSettings(
          accuracy: geo.LocationAccuracy.high,
          distanceFilter: 0,
          intervalDuration: interval,
          foregroundNotificationConfig: const geo.ForegroundNotificationConfig(
            notificationTitle: 'GoMate - Chia sẻ vị trí',
            notificationText: 'Chia sẻ vị trí cho lịch trình đã ghim đang bật.',
            notificationChannelName: 'Chia sẻ vị trí lịch trình',
            notificationIcon: geo.AndroidResource(name: 'ic_stat_gomate'),
            setOngoing: true,
            enableWakeLock: false,
            enableWifiLock: false,
          ),
        ),
      ).map(_sample);
  @override
  Stream<bool> serviceChanges() => geo.Geolocator.getServiceStatusStream().map(
    (s) => s == geo.ServiceStatus.enabled,
  );
}

abstract class PendingUnpinStore {
  Future<Set<String>> pendingTrips(String userId) async => {};
  Future<void> setTripPending(String userId, String tripId, bool value) async {}
}

/// Account-scoped unpin retry metadata only; never consent, GPS or history.
class SecurePendingUnpinStore implements PendingUnpinStore {
  const SecurePendingUnpinStore();
  static const _storage = FlutterSecureStorage();
  static Future<void> _pendingWrite = Future<void>.value();
  String _key(String userId) => 'gomate_pending_unpin_$userId';
  @override
  Future<Set<String>> pendingTrips(String userId) async {
    final value = await _storage.read(key: '${_key(userId)}_trips');
    return value == null
        ? {}
        : (jsonDecode(value) as List).cast<String>().toSet();
  }

  @override
  Future<void> setTripPending(String userId, String tripId, bool value) {
    final write = _pendingWrite.then((_) async {
      final ids = await pendingTrips(userId);
      if (value) {
        ids.add(tripId);
      } else {
        ids.remove(tripId);
      }
      await _storage.write(
        key: '${_key(userId)}_trips',
        value: jsonEncode(ids.toList()),
      );
    });
    _pendingWrite = write.catchError((Object _) {});
    return write;
  }
}

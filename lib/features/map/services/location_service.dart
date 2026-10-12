import 'package:geolocator/geolocator.dart' as geo;

enum GoMateLocationState {
  ready,
  serviceOff,
  permissionDenied,
  permissionDeniedForever,
  whileInUseOnly,
}

class GoMateLocationResult {
  final GoMateLocationState state;
  final geo.Position? position;

  const GoMateLocationResult(this.state, [this.position]);
}

class GoMateLocationService {
  Future<GoMateLocationResult> ensureAlwaysForPinnedTrip() async {
    if (!await geo.Geolocator.isLocationServiceEnabled()) {
      return const GoMateLocationResult(GoMateLocationState.serviceOff);
    }

    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }

    if (permission == geo.LocationPermission.always) {
      return const GoMateLocationResult(GoMateLocationState.ready);
    }

    if (permission == geo.LocationPermission.whileInUse) {
      return const GoMateLocationResult(GoMateLocationState.whileInUseOnly);
    }

    if (permission == geo.LocationPermission.deniedForever) {
      return const GoMateLocationResult(
        GoMateLocationState.permissionDeniedForever,
      );
    }

    return const GoMateLocationResult(GoMateLocationState.permissionDenied);
  }

  Future<void> openAppSettings() => geo.Geolocator.openAppSettings();

  Future<void> openLocationSettings() => geo.Geolocator.openLocationSettings();

  Future<GoMateLocationResult> getCurrentLocation() async {
    if (!await geo.Geolocator.isLocationServiceEnabled()) {
      return const GoMateLocationResult(GoMateLocationState.serviceOff);
    }

    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }

    if (permission == geo.LocationPermission.deniedForever) {
      return const GoMateLocationResult(
        GoMateLocationState.permissionDeniedForever,
      );
    }
    if (permission == geo.LocationPermission.denied) {
      return const GoMateLocationResult(GoMateLocationState.permissionDenied);
    }

    final p = await geo.Geolocator.getCurrentPosition(
      desiredAccuracy: geo.LocationAccuracy.high,
    );
    return GoMateLocationResult(GoMateLocationState.ready, p);
  }
}

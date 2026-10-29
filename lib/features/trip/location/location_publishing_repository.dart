import '../../../core/services/auth_service.dart';
import '../data/trip_repository.dart';
import '../models/trip_ui_models.dart';
import 'location_runtime_models.dart';

class TripLocationPublishingRepository {
  TripLocationPublishingRepository({
    AuthService? auth,
    RealTripRepository? trips,
  }) : _auth = auth ?? AuthService.instance,
       _trips =
           trips ??
           (auth == null
               ? RealTripRepository.instance
               : RealTripRepository(auth: auth));
  final AuthService _auth;
  final RealTripRepository _trips;
  Future<TripUi?> pinned() => _trips.pinned();
  Future<void> unpin(String tripId) => _trips.unpin(tripId);
  Future<DateTime> publish(
    String tripId,
    TripLocationSample sample, {
    required bool background,
  }) async {
    final response = await _auth.request(
      'PUT',
      '/trips/$tripId/location',
      body: {
        'latitude': sample.latitude,
        'longitude': sample.longitude,
        'accuracyM': sample.accuracy,
        'capturedAt': sample.capturedAt.toUtc().toIso8601String(),
        'runtimeMode': background ? 'BACKGROUND' : 'FOREGROUND',
      },
    );
    return DateTime.parse(response['updatedAt'] as String);
  }
}

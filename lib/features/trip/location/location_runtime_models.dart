class TripLocationSample {
  const TripLocationSample(
    this.latitude,
    this.longitude,
    this.accuracy,
    this.capturedAt,
  );
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime capturedAt;
}

class TripLocationCapability {
  const TripLocationCapability({
    required this.serviceOn,
    required this.foregroundAllowed,
    required this.backgroundAllowed,
    this.android = false,
  });
  final bool serviceOn;
  final bool foregroundAllowed;
  final bool backgroundAllowed;
  final bool android;
  bool get canForeground => serviceOn && foregroundAllowed;
  bool get canBackground => android && canForeground && backgroundAllowed;
}

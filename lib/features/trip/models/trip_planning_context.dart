/// Server-provided Trip wall clock. No device timezone or fixed UTC offset.
class TripPlanningContext {
  TripPlanningContext(this.timezone, this.initialWallTime) {
    _elapsed.start();
  }
  final String timezone;
  final DateTime initialWallTime;
  final Stopwatch _elapsed = Stopwatch();
  DateTime get now => initialWallTime.add(_elapsed.elapsed);
  DateTime get today => DateTime(now.year, now.month, now.day);
  factory TripPlanningContext.fromJson(Map<String, dynamic> json) {
    return TripPlanningContext(
      json['timezone'] as String,
      DateTime.parse('${json['localNow']}Z'),
    );
  }
}

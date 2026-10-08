import '../../trip/models/trip_ui_models.dart';
import '../models/map_place.dart';

/// UI-only session state. Không thay đổi gateway/API/backend Map hiện tại.
class GoMateMapUiSession {
  GoMateMapUiSession._();

  static final List<GoMateMapPlace> _recentPlaces = <GoMateMapPlace>[];

  /// TODO(integration): Trip module gọi [pinTrip] khi backend/state ghim
  /// được nối vào MainShell. Khi null, Map tuyệt đối không hiện nút lịch trình.
  static TripUi? _pinnedTrip;

  static List<GoMateMapPlace> get recentPlaces =>
      List<GoMateMapPlace>.unmodifiable(_recentPlaces);

  static TripUi? get pinnedTrip => _pinnedTrip;

  static bool get hasPinnedTrip => _pinnedTrip != null;

  static void pinTrip(TripUi trip) {
    _pinnedTrip = trip;
  }

  static void clearPinnedTrip() {
    _pinnedTrip = null;
  }

  static void addRecent(GoMateMapPlace place) {
    _recentPlaces.removeWhere((item) => item.placeId == place.placeId);
    _recentPlaces.insert(0, place);

    // Search Place mặc định chỉ hiển thị 5 địa điểm gần đây nhất.
    if (_recentPlaces.length > 5) {
      _recentPlaces.removeRange(5, _recentPlaces.length);
    }
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../core/widgets/snackbar.dart';
import '../../trip/data/trip_repository.dart';
import '../../trip/models/trip_ui_models.dart';
import '../services/location_service.dart';
import '../state/map_ui_session.dart';
import 'map_controls.dart';

class GoMateMapTripPinButton extends StatefulWidget {
  final TripUi trip;
  final RealTripRepository tripRepository;
  final GoMateLocationService locationService;
  final double bottomInset;

  const GoMateMapTripPinButton({
    super.key,
    required this.trip,
    required this.tripRepository,
    required this.locationService,
    this.bottomInset = 90,
  });

  @override
  State<GoMateMapTripPinButton> createState() => _GoMateMapTripPinButtonState();
}

class _GoMateMapTripPinButtonState extends State<GoMateMapTripPinButton> {
  bool _saving = false;

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    GoMateSnackBar.show(
      context,
      message: message,
      bottomOffset: widget.bottomInset,
      icon: error ? LucideIcons.circle_alert : LucideIcons.pin,
    );
  }

  Future<void> _pin() async {
    final target = widget.trip;
    if (_saving || GoMateMapUiSession.pinnedTrip?.id == target.id) {
      return;
    }

    final repository = widget.tripRepository;
    final selectionId = GoMateMapUiSession.displayedTrip?.id;
    final locationService = widget.locationService;
    setState(() => _saving = true);
    try {
      final permission = await locationService.ensureAlwaysForPinnedTrip();
      if (!mounted) return;
      switch (permission.state) {
        case GoMateLocationState.serviceOff:
          _showMessage(
            'Hãy bật dịch vụ vị trí trước khi ghim lịch trình.',
            error: true,
          );
          await locationService.openLocationSettings();
          return;
        case GoMateLocationState.whileInUseOnly:
        case GoMateLocationState.permissionDeniedForever:
          _showMessage(
            'Ghim lịch trình cần quyền vị trí Luôn cho phép.',
            error: true,
          );
          await locationService.openAppSettings();
          return;
        case GoMateLocationState.permissionDenied:
          _showMessage(
            'GoMate cần quyền vị trí Luôn cho phép để ghim lịch trình.',
            error: true,
          );
          return;
        case GoMateLocationState.ready:
          break;
      }

      final pinned = await repository.pin(target.id);
      // Keep the server ACK even if navigation removed this button meanwhile.
      GoMateMapUiSession.pinTrip(
        pinned,
        selectOnMap: GoMateMapUiSession.displayedTrip?.id == selectionId,
      );
      _showMessage('Đã ghim lịch trình');
    } catch (error) {
      _showMessage(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _unpin() async {
    if (_saving) return;
    final tripId = widget.trip.id;
    setState(() => _saving = true);
    try {
      await widget.tripRepository.unpin(tripId);
      GoMateMapUiSession.clearPinnedTrip(tripId: tripId);
      _showMessage('Đã bỏ ghim lịch trình');
    } catch (error) {
      _showMessage(error.toString(), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pinned = GoMateMapUiSession.pinnedTrip?.id == widget.trip.id;
    return GoMateMapControlButton(
      key: const ValueKey('map-pin-trip'),
      icon: LucideIcons.pin,
      tooltip: pinned ? 'Bỏ ghim lịch trình' : 'Ghim lịch trình đang xem',
      selected: pinned,
      loading: _saving,
      onTap: _saving ? null : (pinned ? _unpin : _pin),
    );
  }
}

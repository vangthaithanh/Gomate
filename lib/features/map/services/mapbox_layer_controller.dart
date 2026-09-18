import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import '../models/map_member.dart';
import '../models/map_place.dart';
import '../models/map_route.dart';

typedef GoMatePlaceTap = void Function(String placeId);

class GoMateMapboxLayerController {
  MapboxMap? _map;

  PointAnnotationManager? _placeManager;
  PointAnnotationManager? _selectedManager;
  PointAnnotationManager? _tripStopManager;
  PointAnnotationManager? _memberManager;

  PolylineAnnotationManager? _routeShadowManager;
  PolylineAnnotationManager? _routeManager;

  CircleAnnotationManager? _checkinRadiusManager;
  CircleAnnotationManager? _originManager;

  Cancelable? _placeTapSubscription;
  Cancelable? _tripTapSubscription;

  final Map<GoMatePlaceCategory, Uint8List> _categoryImages = {};
  final List<Uint8List> _tripStopImages = [];
  final Map<String, Uint8List> _memberImages = {};
  Uint8List? _selectedImage;

  Future<void> attach(
    MapboxMap map, {
    required GoMatePlaceTap onPlaceTap,
  }) async {
    _map = map;
    await _loadAssets();

    _placeManager =
        await map.annotations.createPointAnnotationManager();
    _selectedManager =
        await map.annotations.createPointAnnotationManager();
    _tripStopManager =
        await map.annotations.createPointAnnotationManager();
    _memberManager =
        await map.annotations.createPointAnnotationManager();

    _routeShadowManager =
        await map.annotations.createPolylineAnnotationManager();
    _routeManager =
        await map.annotations.createPolylineAnnotationManager();

    _checkinRadiusManager =
        await map.annotations.createCircleAnnotationManager();
    _originManager =
        await map.annotations.createCircleAnnotationManager();

    await _placeManager?.setIconAllowOverlap(true);
    await _selectedManager?.setIconAllowOverlap(true);
    await _tripStopManager?.setIconAllowOverlap(true);
    await _memberManager?.setIconAllowOverlap(true);

    _placeTapSubscription = _placeManager?.tapEvents(
      onTap: (annotation) {
        final id = annotation.customData?['placeId']?.toString();
        if (id != null) {
          onPlaceTap(id);
        }
      },
    );

    _tripTapSubscription = _tripStopManager?.tapEvents(
      onTap: (annotation) {
        final id = annotation.customData?['placeId']?.toString();
        if (id != null) {
          onPlaceTap(id);
        }
      },
    );
  }

  Future<void> configureGoMateBaseStyle() async {
    final map = _map;
    if (map == null) return;

    await map.style.setStyleImportConfigProperty(
      'basemap',
      'lightPreset',
      'day',
    );
    await map.style.setStyleImportConfigProperty(
      'basemap',
      'showPointOfInterestLabels',
      false,
    );
    await map.style.setStyleImportConfigProperty(
      'basemap',
      'showPlaceLabels',
      true,
    );
    await map.style.setStyleImportConfigProperty(
      'basemap',
      'showRoadLabels',
      true,
    );
    await map.style.setStyleImportConfigProperty(
      'basemap',
      'showTransitLabels',
      true,
    );
    await map.style.setStyleImportConfigProperty(
      'basemap',
      'showPedestrianRoads',
      true,
    );
    await map.style.setStyleImportConfigProperty(
      'basemap',
      'show3dObjects',
      false,
    );
  }

  Future<void> enableLocationPuck() async {
    final map = _map;
    if (map == null) return;

    await map.location.updateSettings(
      LocationComponentSettings(
        enabled: true,
        pulsingEnabled: false,
        showAccuracyRing: false,
        puckBearingEnabled: false,
      ),
    );
  }

  Future<void> renderPlaces(
    List<GoMateMapPlace> places,
  ) async {
    final manager = _placeManager;
    if (manager == null) return;

    await manager.deleteAll();

    final options = <PointAnnotationOptions>[];

    for (final place in places) {
      final image = _categoryImages[place.category];
      if (image == null) continue;

      options.add(
        PointAnnotationOptions(
          geometry: Point(coordinates: place.position),
          image: image,
          iconAnchor: IconAnchor.BOTTOM,
          iconSize: 1,
          symbolSortKey: 10,
          customData: {'placeId': place.placeId},
        ),
      );
    }

    if (options.isNotEmpty) {
      await manager.createMulti(options);
    }
  }

  Future<void> renderSelected(
    GoMateMapPlace? place,
  ) async {
    final manager = _selectedManager;
    if (manager == null) return;

    await manager.deleteAll();

    if (place == null || _selectedImage == null) {
      return;
    }

    await manager.create(
      PointAnnotationOptions(
        geometry: Point(coordinates: place.position),
        image: _selectedImage,
        iconAnchor: IconAnchor.BOTTOM,
        iconSize: 1,
        symbolSortKey: 100,
        customData: {'placeId': place.placeId},
      ),
    );
  }

  Future<void> clearRouteLayers() async {
    await _routeShadowManager?.deleteAll();
    await _routeManager?.deleteAll();
    await _originManager?.deleteAll();
  }

  Future<void> clearTripLayers() async {
    await clearRouteLayers();
    await _tripStopManager?.deleteAll();
    await _memberManager?.deleteAll();
    await _checkinRadiusManager?.deleteAll();
  }

  Future<void> renderDirections({
    required GoMateMapRoute route,
    required Position origin,
    required GoMateMapPlace destination,
  }) async {
    await clearTripLayers();
    await _placeManager?.deleteAll();
    await _selectedManager?.deleteAll();

    await _drawRouteLine(route);

    await _originManager?.create(
      CircleAnnotationOptions(
        geometry: Point(coordinates: origin),
        circleColor: 0xFF2563EB,
        circleRadius: 8,
        circleStrokeColor: 0xFFFFFFFF,
        circleStrokeWidth: 3,
        circleOpacity: 1,
      ),
    );

    if (_selectedImage != null) {
      await _selectedManager?.create(
        PointAnnotationOptions(
          geometry: Point(coordinates: destination.position),
          image: _selectedImage,
          iconAnchor: IconAnchor.BOTTOM,
          iconSize: 1,
          symbolSortKey: 200,
          customData: {
            'placeId': destination.placeId,
          },
        ),
      );
    }

    await fitRoute(
      route.geometry,
      bottomPadding: 265,
      pitch: 18,
    );
  }

  Future<void> renderTrip({
    required GoMateMapRoute route,
    required List<GoMateMapPlace> stops,
    required List<GoMateMapMember> members,
  }) async {
    await clearTripLayers();
    await _placeManager?.deleteAll();

    await _drawRouteLine(route);

    final stopOptions = <PointAnnotationOptions>[];

    for (var i = 0; i < stops.length; i++) {
      final image = _tripStopImages[
          i < _tripStopImages.length
              ? i
              : _tripStopImages.length - 1];

      stopOptions.add(
        PointAnnotationOptions(
          geometry: Point(coordinates: stops[i].position),
          image: image,
          iconAnchor: IconAnchor.BOTTOM,
          iconSize: 1,
          symbolSortKey: 200 + i.toDouble(),
          customData: {'placeId': stops[i].placeId},
        ),
      );
    }

    if (stopOptions.isNotEmpty) {
      await _tripStopManager?.createMulti(stopOptions);
    }

    final memberOptions = <PointAnnotationOptions>[];

    for (final member in members) {
      final image = _memberImages[member.assetIcon];
      if (image == null) continue;

      memberOptions.add(
        PointAnnotationOptions(
          geometry: Point(coordinates: member.position),
          image: image,
          iconSize: member.isStale ? .88 : 1,
          symbolSortKey: 300,
          customData: {'userId': member.userId},
        ),
      );
    }

    if (memberOptions.isNotEmpty) {
      await _memberManager?.createMulti(memberOptions);
    }

    if (stops.isNotEmpty) {
      await _checkinRadiusManager?.create(
        CircleAnnotationOptions(
          geometry: Point(coordinates: stops.first.position),
          circleColor: 0x2422A06B,
          circleStrokeColor: 0x9922A06B,
          circleStrokeWidth: 2,
          circleRadius: 28,
          circleOpacity: .65,
        ),
      );
    }

    await fitRoute(
      route.geometry,
      bottomPadding: 260,
      pitch: 18,
    );
  }

  Future<void> _drawRouteLine(
    GoMateMapRoute route,
  ) async {
    if (route.geometry.length < 2) return;

    final line = LineString(
      coordinates: route.geometry,
    );

    await _routeShadowManager?.create(
      PolylineAnnotationOptions(
        geometry: line,
        lineColor: 0xFFFFFFFF,
        lineWidth: 11,
        lineOpacity: .96,
        lineJoin: LineJoin.ROUND,
        lineBorderColor: 0x1A0F172A,
        lineBorderWidth: 1.5,
      ),
    );

    await _routeManager?.create(
      PolylineAnnotationOptions(
        geometry: line,
        lineColor: 0xFF2563EB,
        lineWidth: 6.5,
        lineOpacity: 1,
        lineJoin: LineJoin.ROUND,
        lineBorderColor: 0x332563EB,
        lineBorderWidth: 1,
      ),
    );
  }

  Future<void> fitRoute(
    List<Position> coordinates, {
    double bottomPadding = 250,
    double pitch = 18,
  }) async {
    final map = _map;

    if (map == null || coordinates.isEmpty) {
      return;
    }

    try {
      final camera = await map.cameraForCoordinates(
        coordinates
            .map((p) => Point(coordinates: p))
            .toList(),
        MbxEdgeInsets(
          top: 120,
          left: 48,
          bottom: bottomPadding,
          right: 48,
        ),
        0,
        pitch,
      );

      await map.easeTo(
        camera,
        MapAnimationOptions(duration: 750),
      );
    } catch (_) {
      final middle =
          coordinates[coordinates.length ~/ 2];

      await map.easeTo(
        CameraOptions(
          center: Point(coordinates: middle),
          zoom: 13.8,
          pitch: pitch,
          bearing: 0,
        ),
        MapAnimationOptions(duration: 650),
      );
    }
  }

  Future<void> focusPlace(
    GoMateMapPlace place,
  ) async {
    final map = _map;
    if (map == null) return;

    await map.easeTo(
      CameraOptions(
        center: Point(
          coordinates: place.position,
        ),
        zoom: 15.3,
        pitch: 15,
        padding: MbxEdgeInsets(
          top: 80,
          left: 20,
          bottom: 245,
          right: 20,
        ),
      ),
      MapAnimationOptions(duration: 650),
    );
  }

  Future<void> focusCoordinate(
    Position position, {
    double zoom = 16,
  }) async {
    final map = _map;
    if (map == null) return;

    await map.flyTo(
      CameraOptions(
        center: Point(coordinates: position),
        zoom: zoom,
        pitch: 15,
      ),
      MapAnimationOptions(duration: 750),
    );
  }

  Future<void> showExplorePlaces(
    List<GoMateMapPlace> places,
  ) async {
    await clearTripLayers();
    await _selectedManager?.deleteAll();
    await renderPlaces(places);
  }

  void dispose() {
    _placeTapSubscription?.cancel();
    _tripTapSubscription?.cancel();
  }

  Future<Uint8List> _load(
    String path,
  ) async {
    final bytes = await rootBundle.load(path);
    return bytes.buffer.asUint8List();
  }

  Future<void> _loadAssets() async {
    _categoryImages[GoMatePlaceCategory.attraction] =
        await _load('assets/map/pin_attraction.png');

    _categoryImages[GoMatePlaceCategory.cafe] =
        await _load('assets/map/pin_cafe.png');

    _categoryImages[GoMatePlaceCategory.food] =
        await _load('assets/map/pin_food.png');

    _categoryImages[GoMatePlaceCategory.nature] =
        await _load('assets/map/pin_nature.png');

    _categoryImages[GoMatePlaceCategory.shopping] =
        await _load('assets/map/pin_shopping.png');

    _selectedImage =
        await _load('assets/map/pin_selected.png');

    for (var i = 1; i <= 6; i++) {
      _tripStopImages.add(
        await _load(
          'assets/map/trip_stop_$i.png',
        ),
      );
    }

    for (final path in [
      'assets/map/member_an.png',
      'assets/map/member_thu.png',
    ]) {
      _memberImages[path] = await _load(path);
    }
  }
}

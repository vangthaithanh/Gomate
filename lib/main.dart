import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

MapboxOptions.setAccessToken(
  const String.fromEnvironment('MAPBOX_ACCESS_TOKEN'),
);

  runApp(const GoMateApp());
}
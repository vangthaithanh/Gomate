import 'dart:async';

import 'package:flutter/material.dart';
import 'features/auth/screens/splash_screen.dart';
import 'features/notifications/data/notification_push_service.dart';
import 'features/trip/location/trip_location_publishing_service.dart';
import 'features/trip/location/trip_location_realtime_service.dart';

class GoMateApp extends StatefulWidget {
  const GoMateApp({super.key});

  @override
  State<GoMateApp> createState() => _GoMateAppState();
}

class _GoMateAppState extends State<GoMateApp> {
  @override
  void initState() {
    super.initState();
    // main.dart is local/ignored; keep shared push startup in versioned code too.
    unawaited(NotificationPushService.instance.start());
    TripLocationPublishingService.instance.start();
    TripLocationRealtimeService.instance.start();
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}

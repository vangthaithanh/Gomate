import 'package:flutter/material.dart';
import 'features/auth/screens/splash_screen.dart';

class GoMateApp extends StatelessWidget {
  const GoMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SplashScreen(),
    );
  }
}
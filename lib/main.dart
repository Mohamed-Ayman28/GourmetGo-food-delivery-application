import 'package:flutter/material.dart';
import 'package:gourmet_go/screens/CustomerScreens/home_screen.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const GourmetGoApp());
}

class GourmetGoApp extends StatelessWidget {
  const GourmetGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GourmetGo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF5722),
          primary: const Color(0xFFFF5722),
        ),
        fontFamily: 'Roboto',
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

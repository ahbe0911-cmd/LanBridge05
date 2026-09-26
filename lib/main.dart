import 'dart:io';

import 'package:flutter/material.dart';

import 'core/constants.dart';
import 'screens/mobile_pair_screen.dart';
import 'screens/windows_host_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LanBridgeApp());
}

class LanBridgeApp extends StatelessWidget {
  const LanBridgeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF08111F),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4EE8C1),
          brightness: Brightness.dark,
          surface: const Color(0xFF101A2D),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.055),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFF49A9FF)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF4EE8C1),
            foregroundColor: const Color(0xFF07111F),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
      ),
      home: Platform.isWindows
          ? const WindowsHostScreen()
          : Platform.isAndroid
              ? const MobilePairScreen()
              : const _UnsupportedScreen(),
    );
  }
}

class _UnsupportedScreen extends StatelessWidget {
  const _UnsupportedScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('LanBridge 05 currently supports Android and Windows.'),
      ),
    );
  }
}

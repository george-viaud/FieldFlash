import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:field_flash/screens/connect_screen.dart';
import 'package:field_flash/screens/firmware_screen.dart';
import 'package:field_flash/screens/preflash_screen.dart';
import 'package:field_flash/screens/flash_screen.dart';
import 'package:field_flash/screens/settings_screen.dart';

void main() {
  runApp(const ProviderScope(child: FieldFlashApp()));
}

class FieldFlashApp extends StatelessWidget {
  const FieldFlashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FieldFlash',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.orange,
          brightness: Brightness.dark,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const ConnectScreen(),
        '/firmware': (_) => const FirmwareScreen(),
        '/preflash': (_) => const PreFlashScreen(),
        '/flash': (_) => const FlashScreen(),
        '/settings': (_) => const SettingsScreen(),
      },
    );
  }
}

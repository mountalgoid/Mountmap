import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Import Internal
import 'providers/mountmap_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/dashboard_screen.dart'; // Dashboard sebagai gerbang utama
import 'screens/canvas_screen.dart';
import 'theme/app_colors.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => MountMapProvider(),
      child: const MountMapApp(),
    ),
  );
}

class MountMapApp extends StatelessWidget {
  const MountMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MountMapProvider>(
      builder: (context, provider, child) {
        return MaterialApp(
          title: 'MountMap',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: provider.currentTheme == AppThemeMode.dark
                ? Brightness.dark
                : Brightness.light,
            fontFamily: 'Inter',
            // Konfigurasi tema Button standar premium
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: MountMapColors.violet,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          // Memulai aplikasi dari Splash Screen profesional
          home: const MountMapSplashScreen(),
          // Definisi rute untuk navigasi antar halaman
          routes: {
            '/dashboard': (context) => const MountMapDashboard(),
            '/canvas': (context) => const MountMapCanvas(),
          },
        );
      },
    );
  }
}

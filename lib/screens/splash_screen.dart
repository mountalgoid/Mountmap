import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import '../theme/app_colors.dart';
import 'dashboard_screen.dart'; // IMPORT WAJIB: Agar MountMapDashboard dikenali

class MountMapSplashScreen extends StatefulWidget {
  const MountMapSplashScreen({super.key});

  @override
  State<MountMapSplashScreen> createState() => _MountMapSplashScreenState();
}

class _MountMapSplashScreenState extends State<MountMapSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late Animation<double> _fade;

  final LocalAuthentication _auth = LocalAuthentication();
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeIn),
    );

    _mainController.forward().then((_) => _authenticateUser());
  }

  Future<void> _authenticateUser() async {
    try {
      bool canCheckBiometrics = await _auth.canCheckBiometrics;
      bool isDeviceSupported = await _auth.isDeviceSupported();

      if (!canCheckBiometrics || !isDeviceSupported) {
        _navigateToDashboard();
        return;
      }

      setState(() => _isAuthenticating = true);
      bool authenticated = await _auth.authenticate(
        localizedReason: 'Verify to access MountMap',
        options:
            const AuthenticationOptions(stickyAuth: true, biometricOnly: true),
      );

      if (authenticated) {
        _navigateToDashboard();
      } else {
        setState(() => _isAuthenticating = false);
      }
    } on PlatformException catch (_) {
      _navigateToDashboard();
    }
  }

  void _navigateToDashboard() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        // PERBAIKAN: Sekarang MountMapDashboard sudah bisa dipanggil karena sudah di-import
        pageBuilder: (_, __, ___) => const MountMapDashboard(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    final double logoSize = size.width * 0.22;
    final double titleSize = size.width * 0.06;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              MountMapColors.violet,
              Colors.black,
              Colors.black,
              MountMapColors.teal,
            ],
            stops: [0.0, 0.15, 0.85, 1.0],
          ),
        ),
        child: FadeTransition(
          opacity: _fade,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: logoSize,
                height: logoSize,
                constraints:
                    const BoxConstraints(maxWidth: 100, maxHeight: 100),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: MountMapColors.violet.withValues(alpha: 0.1),
                      blurRadius: 40,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/logo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => Icon(Icons.terrain_rounded,
                      size: logoSize * 0.5, color: Colors.white),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                "MOUNTMAP",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: titleSize > 24 ? 24 : titleSize,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                ),
              ),
              const SizedBox(height: 64),
              _isAuthenticating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white10),
                      ),
                    )
                  : Icon(Icons.fingerprint,
                      color: Colors.white10, size: titleSize),
            ],
          ),
        ),
      ),
    );
  }
}

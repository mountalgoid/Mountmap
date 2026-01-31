import "package:flutter/material.dart";
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class AuthService {
  static final _auth = LocalAuthentication();

  static Future<bool> authenticate() async {
    try {
      // Cek apakah perangkat mendukung biometrik
      final isAvailable = await _auth.canCheckBiometrics;
      final isDeviceSupported = await _auth.isDeviceSupported();

      if (!isAvailable || !isDeviceSupported) return false;

      return await _auth.authenticate(
        localizedReason: 'Scan biometrik untuk membuka MountMap',
        options: const AuthenticationOptions(
          stickyAuth: true, // Menjaga auth tetap aktif jika app ke background
          biometricOnly: true,
        ),
      );
    } on PlatformException catch (e) {
      debugPrint("Error Biometric: $e");
      return false;
    }
  }
}

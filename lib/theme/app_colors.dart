import 'package:flutter/material.dart';

class MountMapColors {
  // Core Branding
  static const Color violet = Color(0xFF5134FF);
  static const Color teal = Color(0xFF089981);

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [violet, teal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Backgrounds
  static const Color darkBackground = Color(0xFF0D1117);
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color warmBackground = Color(0xFFFDF6E3);

  // Cards
  static const Color darkCard = Color(0xFF161B22);
  static const Color lightCard = Colors.white;
  static const Color warmCard = Color(0xFFEEE8D5);

  // Texts
  static const Color darkText = Color(0xFFE6EDF3);
  static const Color lightText = Color(0xFF212529);
  static const Color warmText = Color(0xFF586E75);

  // Accent / Interactive
  static const Color accentTeal = Color(0xFF00FFD1);
  static const Color accentAmber = Color(0xFFFFC107);
}

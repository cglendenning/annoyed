import 'package:flutter/material.dart';

/// App color palette based on icon color #0F766E
class AppColors {
  // Primary teal (from icon)
  static const Color primaryTeal = Color(0xFF0F766E);
  static const Color primaryTealLight = Color(0xFF14B8A6); // Lighter teal
  static const Color primaryTealDark = Color(0xFF0D5B55); // Darker teal
  
  // Complementary coral/rose
  static const Color accentCoral = Color(0xFF760F16);
  static const Color accentCoralLight = Color(0xFFEF4444); // Lighter coral
  static const Color accentCoralSoft = Color(0xFFFCA5A5); // Soft coral
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryTealLight, primaryTeal, primaryTealDark],
  );
  
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accentCoralLight, accentCoral],
  );
  
  static const LinearGradient meshGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      primaryTealLight,
      primaryTeal,
      accentCoral,
      accentCoralLight,
    ],
    stops: [0.0, 0.3, 0.7, 1.0],
  );
  
  static const LinearGradient subtleGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFF0FDFA), // Very light teal
      Colors.white,
    ],
  );
  
  // Shimmer effect for animations
  static LinearGradient shimmerGradient({double offset = 0.0}) {
    return LinearGradient(
      begin: Alignment(-1.0 + offset, -1.0),
      end: Alignment(1.0 + offset, 1.0),
      colors: const [
        Color(0xFFE0F2F1),
        Color(0xFF14B8A6),
        Color(0xFFE0F2F1),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
  }
}


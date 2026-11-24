import 'package:flutter/material.dart';

class AppColors {
  // Brand primary: yellow — premium ride-app identity
  static const Color primary = Color(0xFFFFC107);
  static const Color primaryLight = Color(0xFFFFD54F);
  static const Color primaryDark = Color(0xFFFFA000);

  // Legacy blue retained for reference / secondary use
  static const Color secondary = Color(0xFF1976D2);
  static const Color accent = Color(0xFF4CAF50);

  // Dark charcoal surface — premium dark feel
  static const Color dark = Color(0xFF1A1A2E);
  static const Color darkSurface = Color(0xFF16213E);
  static const Color darkVariant = Color(0xFF0F3460);

  // Semantic
  static const Color error = Color(0xFFE53E3E);
  static const Color warning = Color(0xFFFF9800);
  static const Color success = Color(0xFF10B981);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // Light surface palette
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9);
  static const Color outline = Color(0xFFE2E8F0);
  static const Color outlineVariant = Color(0xFFCBD5E1);

  // Text
  static const Color onSurface = Color(0xFF1E293B);
  static const Color onSurfaceVariant = Color(0xFF64748B);
  static const Color onBackground = Color(0xFF0F172A);
  static const Color onDark = Color(0xFFFFFFFF);
  static const Color onPrimary = Color(0xFF1A1A2E);

  // Service tile colours
  static const Color bikeTaxi = Color(0xFF1976D2);
  static const Color courier = Color(0xFF10B981);
  static const Color auto = Color(0xFFFF9800);
  static const Color miniTruck = Color(0xFF8B5CF6);
  static const Color truck = Color(0xFF6366F1);

  // Ride status colours
  static const Color requested = Color(0xFFF59E0B);
  static const Color accepted = Color(0xFF3B82F6);
  static const Color arrived = Color(0xFF8B5CF6);
  static const Color started = Color(0xFF10B981);
  static const Color completed = Color(0xFF059669);
  static const Color cancelled = Color(0xFFEF4444);

  // Shadow
  static const Color shadow = Color(0x1A000000);
  static const Color shadowLight = Color(0x0D000000);

  // ── Gradients ──────────────────────────────────────────────────────────────

  /// Dark charcoal → brand yellow  (splash, hero banners)
  static const LinearGradient brandGradient = LinearGradient(
    colors: [Color(0xFF1A1A2E), Color(0xFFFFC107)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  /// Yellow shimmer  (buttons, cards)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFFC107), Color(0xFFFFD54F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Charcoal horizontal (AppBar, drawer header)
  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF34D399)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

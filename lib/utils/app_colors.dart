import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF1976D2);
  static const Color primaryLight = Color(0xFF42A5F5);
  static const Color primaryDark = Color(0xFF1565C0);
  static const Color secondary = Color(0xFFFFC107);
  static const Color accent = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53E3E);
  static const Color warning = Color(0xFFFF9800);
  static const Color success = Color(0xFF10B981);
  
  // Modern UI Colors
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9);
  static const Color outline = Color(0xFFE2E8F0);
  static const Color outlineVariant = Color(0xFFCBD5E1);
  
  // Text Colors
  static const Color onSurface = Color(0xFF1E293B);
  static const Color onSurfaceVariant = Color(0xFF64748B);
  static const Color onBackground = Color(0xFF0F172A);
  
  // Semantic Colors
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);
  
  // Service Colors with modern palette
  static const Color bikeTaxi = Color(0xFF1976D2);
  static const Color courier = Color(0xFF10B981);
  static const Color auto = Color(0xFFFF9800);
  static const Color miniTruck = Color(0xFF8B5CF6);
  static const Color truck = Color(0xFF6366F1);
  
  // Status Colors
  static const Color requested = Color(0xFFF59E0B);
  static const Color accepted = Color(0xFF3B82F6);
  static const Color arrived = Color(0xFF8B5CF6);
  static const Color started = Color(0xFF10B981);
  static const Color completed = Color(0xFF059669);
  static const Color cancelled = Color(0xFFEF4444);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
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
  
  // Shadow Colors
  static const Color shadow = Color(0x1A000000);
  static const Color shadowLight = Color(0x0D000000);
}
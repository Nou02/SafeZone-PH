import 'package:flutter/material.dart';

/// App-wide color constants for consistent theming
class AppColors {
  // Primary brand color (red/orange)
  static const Color primary = Color(0xFFE25749);
  
  // Status colors
  static const Color statusPending = Color(0xFFFF9800); // Orange
  static const Color statusResponding = Color(0xFF2196F3); // Blue
  static const Color statusResolved = Color(0xFF4CAF50); // Green
  
  // Report type colors
  static const Color reportCrime = Color(0xFFE25749); // Red (same as primary)
  static const Color reportAccident = Color(0xFFFF9800); // Orange
  static const Color reportHazard = Color(0xFFFFC107); // Amber
  
  // Neutral colors
  static const Color background = Color(0xFFF7F9FA);
  static const Color cardBackground = Colors.white;
  static const Color borderLight = Color(0x0F000000); // 6% opacity black
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  
  // Map colors
  static const Color mapUserLocation = Color(0xFF2196F3); // Blue accent
  static const Color mapReportMarker = Color(0xFFE25749); // Red (primary)
  static const Color mapBarangayHall = Color(0xFF1976D2); // Blue
}








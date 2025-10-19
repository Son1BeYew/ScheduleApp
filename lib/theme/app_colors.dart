import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary Colors - Modern blue gradient
  static const primary = Color(0xFF4F46E5);
  static const primaryLight = Color(0xFF6366F1);
  static const primaryDark = Color(0xFF4338CA);
  
  // Secondary Colors - Accent purple
  static const secondary = Color(0xFF7C3AED);
  static const secondaryLight = Color(0xFF8B5CF6);
  static const secondaryDark = Color(0xFF6D28D9);
  
  // Accent Colors
  static const accent = Color(0xFF06B6D4);
  static const accentLight = Color(0xFF22D3EE);
  
  // Neutral Colors
  static const background = Color(0xFFF9FAFB);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF3F4F6);
  
  // Text Colors
  static const textPrimary = Color(0xFF111827);
  static const textSecondary = Color(0xFF6B7280);
  static const textTertiary = Color(0xFF9CA3AF);
  static const textOnPrimary = Color(0xFFFFFFFF);
  
  // Border Colors
  static const border = Color(0xFFE5E7EB);
  static const borderLight = Color(0xFFF3F4F6);
  
  // Status Colors
  static const success = Color(0xFF10B981);
  static const successLight = Color(0xFFD1FAE5);
  static const warning = Color(0xFFF59E0B);
  static const warningLight = Color(0xFFFEF3C7);
  static const error = Color(0xFFEF4444);
  static const errorLight = Color(0xFFFEE2E2);
  static const info = Color(0xFF3B82F6);
  static const infoLight = Color(0xFFDCEEFE);
  
  // Gradient Colors
  static const gradientPurple = LinearGradient(
    colors: [Color(0xFFEEF1FF), Color(0xFFF6F2FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const gradientBlue = LinearGradient(
    colors: [Color(0xFFE0F2FE), Color(0xFFDDD6FE)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const gradientAccent = LinearGradient(
    colors: [Color(0xFFF7E9FF), Color(0xFFE3F2FF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  // Shadow Colors
  static final shadowSm = Colors.black.withValues(alpha: 0.05);
  static final shadowMd = Colors.black.withValues(alpha: 0.1);
  static final shadowLg = Colors.black.withValues(alpha: 0.15);
  
  // Schedule Timeline Colors
  static const timelineActive = Color(0xFF1F2937);
  static const timelineInactive = Color(0xFFE0E7FF);
  static const timelineBackground = Color(0xFFF5F8FF);
  
  // Note Category Colors
  static const categoryBlue = Color(0xFFEFF5FF);
  static const categoryPurple = Color(0xFFF5F3FF);
  static const categoryGreen = Color(0xFFECFDF5);
  static const categoryYellow = Color(0xFFFFF0D3);
  static const categoryRed = Color(0xFFFEE2E2);
  
  // Overlay Colors
  static final overlay = Colors.black.withValues(alpha: 0.4);
  static final overlayLight = Colors.black.withValues(alpha: 0.2);
}

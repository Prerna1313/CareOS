import 'package:flutter/material.dart';

/// CareOS "Serene Sanctuary" Design System Colors
/// Extracted from Stitch AI design system.
class AppColors {
  AppColors._();

  // ── Primary ──
  static const Color primary = Color(0xFF3D637E);
  static const Color primaryDim = Color(0xFF305771);
  static const Color primaryContainer = Color(0xFFB8DFFE);
  static const Color onPrimary = Color(0xFFF5F9FF);
  static const Color onPrimaryContainer = Color(0xFF29506A);
  static const Color primaryFixed = Color(0xFFB8DFFE);
  static const Color primaryFixedDim = Color(0xFFAAD1EF);
  static const Color onPrimaryFixed = Color(0xFF123E56);
  static const Color onPrimaryFixedVariant = Color(0xFF335A74);

  // ── Secondary ──
  static const Color secondary = Color(0xFF4A6800);
  static const Color secondaryDim = Color(0xFF405B00);
  static const Color secondaryContainer = Color(0xFFC8F17A);
  static const Color onSecondary = Color(0xFFF0FFCE);
  static const Color onSecondaryContainer = Color(0xFF3F5A00);
  static const Color onSecondaryFixed = Color(0xFF304600);
  static const Color onSecondaryFixedVariant = Color(0xFF476400);

  // ── Tertiary ──
  static const Color tertiary = Color(0xFF565D85);
  static const Color tertiaryDim = Color(0xFF4A5178);
  static const Color tertiaryContainer = Color(0xFFC9CFFE);
  static const Color onTertiary = Color(0xFFFAF8FF);
  static const Color onTertiaryContainer = Color(0xFF3E456C);

  // ── Surface ──
  static const Color surface = Color(0xFFFAFAF5);
  static const Color surfaceBright = Color(0xFFFAFAF5);
  static const Color surfaceDim = Color(0xFFD8DBD3);
  static const Color surfaceContainer = Color(0xFFEDEFE8);
  static const Color surfaceContainerHigh = Color(0xFFE7E9E2);
  static const Color surfaceContainerHighest = Color(0xFFE0E4DC);
  static const Color surfaceContainerLow = Color(0xFFF3F4EE);
  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFE0E4DC);
  static const Color surfaceTint = Color(0xFF3D637E);
  static const Color onSurface = Color(0xFF2F342E);
  static const Color onSurfaceVariant = Color(0xFF5C605A);
  static const Color onBackground = Color(0xFF2F342E);
  static const Color background = Color(0xFFFAFAF5);

  // ── Error ──
  static const Color error = Color(0xFFA83836);
  static const Color errorContainer = Color(0xFFFA746F);
  static const Color onError = Color(0xFFFFF7F6);
  static const Color onErrorContainer = Color(0xFF6E0A12);
  static const Color errorDim = Color(0xFF67040D);

  // ── Outline ──
  static const Color outline = Color(0xFF787C75);
  static const Color outlineVariant = Color(0xFFAFB3AC);

  // ── Inverse ──
  static const Color inverseSurface = Color(0xFF0D0F0C);
  static const Color inverseOnSurface = Color(0xFF9C9D99);
  static const Color inversePrimary = Color(0xFFB8DFFE);

  // ── Success (Green) ──
  static const Color success = Color(0xFF4A6800);
  static const Color successContainer = Color(0xFFC8F17A);
  static const Color onSuccess = Color(0xFFF0FFCE);

  // ── Brand Overrides (from Stitch) ──
  static const Color brandPrimary = Color(0xFF5D8AA8);
  static const Color overridePrimary = Color(0xFF4A708B);
  static const Color overrideSecondary = Color(0xFF6B8E23);
  static const Color overrideNeutral = Color(0xFFF5F5F0);

  // ── Gradients ──
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDim],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF3D637E), Color(0xFF4A708B), Color(0xFF5D8AA8)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Compatibility aliases used by some caregiver/patient screens imported
  // from earlier design iterations.
  static const Color primaryColor = primary;
  static const Color secondaryColor = secondary;
  static const Color tertiaryColor = tertiary;
  static const Color surfaceColor = surface;
  static const Color textColor = onSurface;
  static const Color errorColor = error;
  static const Color successColor = success;
}

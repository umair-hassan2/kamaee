import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // ── Brand ──────────────────────────────────────────────────────────────────
  static const primary      = Color(0xFF7C3AED); // Violet-600
  static const primaryDark  = Color(0xFF6D28D9); // Violet-700
  static const primaryLight = Color(0xFFEDE9FE); // Violet-100

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const sell         = Color(0xFF16A34A); // Green-600
  static const sellLight    = Color(0xFFDCFCE7); // Green-100
  static const danger       = Color(0xFFDC2626); // Red-600
  static const dangerLight  = Color(0xFFFEE2E2); // Red-100
  static const warning      = Color(0xFFEA580C); // Orange-600
  static const warningLight = Color(0xFFFFF7ED); // Orange-50
  static const accent       = Color(0xFF0891B2); // Cyan-600

  // ── Neutrals ───────────────────────────────────────────────────────────────
  static const surface      = Color(0xFFFAFAF9); // Stone-50  (warm off-white)
  static const card         = Colors.white;
  static const border       = Color(0xFFE7E5E4); // Stone-200
  static const muted        = Color(0xFF78716C); // Stone-500
  static const mutedLight   = Color(0xFFA8A29E); // Stone-400
  static const neutralDark  = Color(0xFF1C1917); // Stone-900
  static const restock      = Color(0xFF2563EB); // Blue-600
}

class AppTheme {
  static ThemeData get light {
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: AppColors.surface,
      textTheme: _buildTextTheme(),

      // ── AppBar ────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.neutralDark,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black.withValues(alpha: 0.06),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.neutralDark,
        ),
      ),

      // ── Cards ─────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),

      // ── Navigation Bar ────────────────────────────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.primaryLight,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.primary : AppColors.muted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.primary : AppColors.muted,
            size: 22,
          );
        }),
      ),

      // ── Buttons ───────────────────────────────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          side: const BorderSide(color: AppColors.primary),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),

      // ── Inputs ────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        labelStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.muted),
        hintStyle: GoogleFonts.inter(fontSize: 14, color: AppColors.mutedLight),
      ),

      // ── Chips ─────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: const BorderSide(color: AppColors.border),
        labelStyle: GoogleFonts.inter(fontSize: 12),
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),

      // ── BottomSheet ───────────────────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      // ── Dialog ────────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.neutralDark,
        ),
      ),

      // ── SnackBar ──────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.neutralDark,
        contentTextStyle: GoogleFonts.inter(fontSize: 14, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // ── TabBar ────────────────────────────────────────────────────────────
      tabBarTheme: TabBarThemeData(
        labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 13),
        indicatorSize: TabBarIndicatorSize.tab,
      ),
    );
  }

  static TextTheme _buildTextTheme() {
    return TextTheme(
      displayLarge: GoogleFonts.plusJakartaSans(
          fontSize: 36, fontWeight: FontWeight.bold, color: AppColors.neutralDark),
      displayMedium: GoogleFonts.plusJakartaSans(
          fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.neutralDark),
      headlineLarge: GoogleFonts.plusJakartaSans(
          fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.neutralDark),
      headlineMedium: GoogleFonts.plusJakartaSans(
          fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.neutralDark),
      headlineSmall: GoogleFonts.plusJakartaSans(
          fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.neutralDark),
      titleLarge: GoogleFonts.inter(
          fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.neutralDark),
      titleMedium: GoogleFonts.inter(
          fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.neutralDark),
      titleSmall: GoogleFonts.inter(
          fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.neutralDark),
      bodyLarge: GoogleFonts.inter(fontSize: 16, color: AppColors.neutralDark),
      bodyMedium: GoogleFonts.inter(fontSize: 14, color: AppColors.neutralDark),
      bodySmall: GoogleFonts.inter(fontSize: 13, color: AppColors.muted),
      labelLarge: GoogleFonts.inter(
          fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.muted,
          letterSpacing: 0.3),
      labelMedium: GoogleFonts.inter(fontSize: 11, color: AppColors.muted),
      labelSmall: GoogleFonts.inter(
          fontSize: 10, fontWeight: FontWeight.w500, color: AppColors.mutedLight,
          letterSpacing: 0.4),
    );
  }
}

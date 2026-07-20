import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // ── Core palette ───────────────────────────────────────────────────────────
  static const ink        = Color(0xFF17140E);
  static const inkMuted   = Color(0xFF8E877A);
  static const green      = Color(0xFF12734E);
  static const greenDark  = Color(0xFF0E5E40);
  static const greenBright= Color(0xFF5FCF9A);
  static const greenFrame = Color(0xFF3FBE85);
  static const amber      = Color(0xFFA96A12);
  static const amberDark  = Color(0xFF8A5510);
  static const red        = Color(0xFFB93B32);
  static const teal       = Color(0xFF1B7C88);
  static const tealDark   = Color(0xFF146A74);
  static const blue       = Color(0xFF2F6DB0);

  // ── Tints ──────────────────────────────────────────────────────────────────
  static const greenLight = Color(0xFFE3F1E9);
  static const amberLight = Color(0xFFF7EBD5);
  static const redLight   = Color(0xFFF7E2DF);
  static const tealLight  = Color(0xFFDEEFF0);
  static const blueLight  = Color(0xFFE2ECF6);

  // ── Surfaces ───────────────────────────────────────────────────────────────
  static const paper      = Color(0xFFF6F3EC);
  static const paperDark  = Color(0xFFF1ECE1);
  static const card       = Colors.white;
  static const border     = Color(0xFFEAE3D6);
  static const borderDark = Color(0xFFE5DECF);
  static const muted      = Color(0xFF8B8173);
  static const mutedLight = Color(0xFFB4AB9C);
  static const secondary  = Color(0xFF5A5142);
  static const onDark     = Color(0xFFFBF9F3);

  // ── Legacy aliases (keep existing screens compiling) ─────────────────────
  static const primary      = green;
  static const primaryDark  = greenDark;
  static const primaryLight = greenLight;
  static const sell         = green;
  static const sellLight    = greenLight;
  static const danger       = red;
  static const dangerLight  = redLight;
  static const warning      = amber;
  static const warningLight = amberLight;
  static const accent       = teal;
  static const surface      = paper;
  static const neutralDark  = ink;
  static const restock      = blue;
}

// ── Font helpers ──────────────────────────────────────────────────────────────

TextStyle bricolage({
  double fontSize = 16,
  FontWeight fontWeight = FontWeight.w700,
  Color color = AppColors.ink,
  double? letterSpacing,
  double? height,
}) =>
    GoogleFonts.bricolageGrotesque(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );

TextStyle instrument({
  double fontSize = 14,
  FontWeight fontWeight = FontWeight.w400,
  Color color = AppColors.ink,
  double? letterSpacing,
}) =>
    GoogleFonts.instrumentSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );

TextStyle mono({
  double fontSize = 14,
  FontWeight fontWeight = FontWeight.w400,
  Color color = AppColors.ink,
  double? letterSpacing,
}) =>
    GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );

// ── Theme ─────────────────────────────────────────────────────────────────────

class AppTheme {
  static ThemeData get light {
    final base = ColorScheme.fromSeed(
      seedColor: AppColors.green,
      brightness: Brightness.light,
      primary: AppColors.green,
      secondary: AppColors.amber,
      surface: AppColors.paper,
      error: AppColors.red,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: base,
      scaffoldBackgroundColor: AppColors.paper,
      textTheme: _buildTextTheme(),

      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.paper,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: bricolage(fontSize: 20, fontWeight: FontWeight.w700),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return instrument(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? Colors.white : AppColors.inkMuted,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? Colors.white : AppColors.inkMuted,
            size: 22,
          );
        }),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
          textStyle: instrument(
              fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.green,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: AppColors.green),
          textStyle: instrument(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.green,
          textStyle: instrument(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
          borderSide: const BorderSide(color: AppColors.green, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.red),
        ),
        labelStyle: instrument(fontSize: 14, color: AppColors.muted),
        hintStyle: instrument(fontSize: 14, color: AppColors.mutedLight),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        side: const BorderSide(color: AppColors.border),
        labelStyle: instrument(fontSize: 12),
      ),

      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: bricolage(fontSize: 18, fontWeight: FontWeight.w700),
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        contentTextStyle: instrument(fontSize: 14, color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      tabBarTheme: TabBarThemeData(
        labelStyle:
            instrument(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
        unselectedLabelStyle:
            instrument(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.muted),
        indicatorColor: AppColors.ink,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: AppColors.border,
      ),
    );
  }

  static TextTheme _buildTextTheme() {
    return TextTheme(
      displayLarge: bricolage(fontSize: 36, fontWeight: FontWeight.w800),
      displayMedium: bricolage(fontSize: 28, fontWeight: FontWeight.w700),
      headlineLarge: bricolage(fontSize: 24, fontWeight: FontWeight.w700),
      headlineMedium: bricolage(fontSize: 20, fontWeight: FontWeight.w700),
      headlineSmall: bricolage(fontSize: 18, fontWeight: FontWeight.w700),
      titleLarge: instrument(
          fontSize: 16, fontWeight: FontWeight.w600),
      titleMedium: instrument(
          fontSize: 15, fontWeight: FontWeight.w500),
      titleSmall: instrument(
          fontSize: 14, fontWeight: FontWeight.w500),
      bodyLarge: instrument(fontSize: 16),
      bodyMedium: instrument(fontSize: 14),
      bodySmall: instrument(fontSize: 13, color: AppColors.muted),
      labelLarge: instrument(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.muted,
          letterSpacing: 0.14),
      labelMedium: instrument(fontSize: 11, color: AppColors.muted),
      labelSmall: instrument(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: AppColors.mutedLight,
          letterSpacing: 0.14),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Eco-Tech Color Palette
  static const Color primaryForest = Color(0xFF143627);
  static const Color primaryEmerald = Color(0xFF16A34A);
  static const Color primaryGlow = Color(0xFF22C55E);
  static const Color accentLime = Color(0xFFA3E635);
  static const Color accentAmber = Color(0xFFF59E0B);
  static const Color accentCoral = Color(0xFFEF4444);
  static const Color accentCyan = Color(0xFF06B6D4);

  // Backgrounds & Surface
  static const Color bgDark = Color(0xFF0D1511);
  static const Color bgSurface = Color(0xFF16221C);
  static const Color bgSurfaceHover = Color(0xFF1C2B23);
  static const Color borderSubtle = Color(0xFF25392E);

  // Text Colors
  static const Color textMain = Color(0xFFF0FDF4);
  static const Color textMuted = Color(0xFF94A39B);
  static const Color textSubtle = Color(0xFF64746D);

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme(ThemeData.dark().textTheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      primaryColor: primaryEmerald,
      colorScheme: const ColorScheme.dark(
        primary: primaryGlow,
        secondary: accentLime,
        surface: bgSurface,
        error: accentCoral,
        onPrimary: Colors.white,
        onSurface: textMain,
      ),
      cardTheme: CardThemeData(
        color: bgSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderSubtle, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: bgDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: GoogleFonts.spaceGrotesk(
          color: textMain,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: const IconThemeData(color: textMain),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          splashFactory: InkSparkle.splashFactory,
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return const Color(0xFF22C55E);
            }
            if (states.contains(WidgetState.hovered)) {
              return const Color(0xFF16A34A);
            }
            return primaryEmerald;
          }),
          foregroundColor: WidgetStateProperty.all(Colors.white),
          elevation: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) return 1.0;
            if (states.contains(WidgetState.hovered)) return 6.0;
            return 3.0;
          }),
          shadowColor: WidgetStateProperty.all(const Color(0x6622C55E)),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          textStyle: WidgetStateProperty.all(
            GoogleFonts.plusJakartaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          splashFactory: InkSparkle.splashFactory,
          foregroundColor: WidgetStateProperty.all(Colors.white),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return const BorderSide(color: Color(0xFF22C55E), width: 2);
            }
            return const BorderSide(color: borderSubtle, width: 1);
          }),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF0A100D),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryGlow, width: 1.5),
        ),
        labelStyle: const TextStyle(color: textMuted),
        hintStyle: const TextStyle(color: textSubtle),
      ),
      textTheme: baseTextTheme.copyWith(
        headlineLarge: GoogleFonts.spaceGrotesk(
          color: textMain,
          fontSize: 28,
          fontWeight: FontWeight.w800,
        ),
        headlineMedium: GoogleFonts.spaceGrotesk(
          color: textMain,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
        titleLarge: GoogleFonts.spaceGrotesk(
          color: textMain,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: const TextStyle(color: textMain, fontSize: 15),
        bodyMedium: const TextStyle(color: textMuted, fontSize: 13),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF101B15),
        selectedItemColor: primaryGlow,
        unselectedItemColor: textSubtle,
        type: BottomNavigationBarType.fixed,
        elevation: 10,
      ),
    );
  }
}

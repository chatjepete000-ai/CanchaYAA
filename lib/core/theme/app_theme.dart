import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const Color primary = Color(0xFF0B8F4D);
  static const Color brightGreen = Color(0xFF43E97B);

  static const Color lightBackground = Color(0xFFF5F8F6);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightInk = Color(0xFF102018);

  static const Color darkBackground = Color(0xFF04110D);
  static const Color darkSurface = Color(0xFF081A14);
  static const Color darkSurfaceElevated = Color(0xFF0D241C);
  static const Color darkInk = Color(0xFFF4FFF8);

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: primary,
      brightness: Brightness.light,
      surface: lightSurface,
    ).copyWith(
      primary: primary,
      secondary: brightGreen,
      surface: lightSurface,
      onSurface: lightInk,
      outlineVariant: const Color(0xFFDCE6E0),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: lightBackground,

      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: lightInk,
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: lightSurface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(
            color: Color(0xFFE3EBE6),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFD9E3DD),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFFD9E3DD),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: primary,
            width: 1.6,
          ),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFDDF8E7),
        labelBehavior:
            NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(
                color: primary,
              );
            }

            return const IconThemeData(
              color: Color(0xFF59655F),
            );
          },
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                color: primary,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              );
            }

            return const TextStyle(
              color: Color(0xFF59655F),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            );
          },
        ),
      ),

      dividerColor: const Color(0xFFE1E9E4),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontWeight: FontWeight.w900,
          color: lightInk,
        ),
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w900,
          color: lightInk,
        ),
        headlineSmall: TextStyle(
          fontWeight: FontWeight.w900,
          color: lightInk,
        ),
        titleLarge: TextStyle(
          fontWeight: FontWeight.w800,
          color: lightInk,
        ),
        titleMedium: TextStyle(
          fontWeight: FontWeight.w700,
          color: lightInk,
        ),
        bodyLarge: TextStyle(
          color: lightInk,
        ),
        bodyMedium: TextStyle(
          color: Color(0xFF536159),
        ),
      ),
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: brightGreen,
      brightness: Brightness.dark,
      surface: darkSurface,
    ).copyWith(
      primary: brightGreen,
      secondary: primary,
      surface: darkSurface,
      onSurface: darkInk,
      outlineVariant: const Color(0xFF1D3B2F),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkBackground,

      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: darkInk,
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: darkSurface,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(
            color: Color(0xFF17422F),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurfaceElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF82998E),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF214536),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF214536),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: brightGreen,
            width: 1.6,
          ),
        ),
      ),

      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: const Color(0xFF061610),
        indicatorColor: const Color(0xFF113925),
        labelBehavior:
            NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(
                color: brightGreen,
              );
            }

            return const IconThemeData(
              color: Color(0xFF9BABA3),
            );
          },
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                color: brightGreen,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              );
            }

            return const TextStyle(
              color: Color(0xFF9BABA3),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            );
          },
        ),
      ),

      dividerColor: const Color(0xFF173329),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontWeight: FontWeight.w900,
          color: darkInk,
        ),
        headlineMedium: TextStyle(
          fontWeight: FontWeight.w900,
          color: darkInk,
        ),
        headlineSmall: TextStyle(
          fontWeight: FontWeight.w900,
          color: darkInk,
        ),
        titleLarge: TextStyle(
          fontWeight: FontWeight.w800,
          color: darkInk,
        ),
        titleMedium: TextStyle(
          fontWeight: FontWeight.w700,
          color: darkInk,
        ),
        bodyLarge: TextStyle(
          color: darkInk,
        ),
        bodyMedium: TextStyle(
          color: Color(0xFFA9BCB2),
        ),
      ),
    );
  }
}
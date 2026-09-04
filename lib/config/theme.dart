import 'package:flutter/material.dart';

class AppTheme {
  // Government-style color palette
  static const Color primaryColor = Color(0xFF1A237E);
  static const Color secondaryColor = Color(0xFFC5A44E);
  static const Color accentColor = Color(0xFF2E7D32);
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,

      // IMPORTANT: Set font family and fallbacks
      fontFamily: 'NotoSansThai',
      fontFamilyFallback: const [
        'Sarabun',
        'NotoSansThai',
        'Kanit',
        'Tahoma',
        'sans-serif',
      ],

      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        secondary: secondaryColor,
        surface: cardColor,
        brightness: Brightness.light,
      ),

      // Define text theme with Sarabun
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        titleLarge: TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 16,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 14,
          color: textSecondary,
        ),
        bodySmall: TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 12,
          color: textSecondary,
        ),
        labelLarge: TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),

      // AppBar theme
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),

      // Card theme
      cardTheme: CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: cardColor,
      ),

      // Elevated button theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontFamily: 'NotoSansThai',
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // List tile theme
       // Fix ListTile ink splash visibility
       // ListTile theme - CORRECTED
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: primaryColor.withValues(alpha: 0.1),
        selectedColor: primaryColor,
        iconColor: primaryColor,
        textColor: textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        enableFeedback: true,
        visualDensity: VisualDensity.standard,
      ),

      // Fix splash factory globally
      splashFactory: InkRipple.splashFactory,
      highlightColor: primaryColor.withValues(alpha: 0.1),
      splashColor: primaryColor.withValues(alpha: 0.15),

      // Input decoration theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        hintStyle: const TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 16,
          color: textSecondary,
        ),
        labelStyle: const TextStyle(
          fontFamily: 'NotoSansThai',
          fontSize: 16,
          color: textPrimary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.grey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),

      // Bottom navigation bar theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(fontFamily: 'NotoSansThai', fontSize: 12),
        unselectedLabelStyle: TextStyle(fontFamily: 'NotoSansThai', fontSize: 12),
      ),

      // Drawer theme
      drawerTheme: const DrawerThemeData(
        backgroundColor: Colors.white,
        elevation: 16,
      ),

      // Snackbar theme
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        contentTextStyle: const TextStyle(fontFamily: 'NotoSansThai', fontSize: 14),
      ),

      scaffoldBackgroundColor: backgroundColor,

      dividerTheme: const DividerThemeData(
        color: Color(0xFFE0E0E0),
        thickness: 1,
      ),
    );
  }
}

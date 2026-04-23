import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Healthcare clinic color palette - Dark mode
// Using lighter blue for better visibility on dark backgrounds
const Color _primaryColor = Color(0xFF42A5F5);
const Color _secondaryColor = Color(0xFF66BB6A);

ThemeData darkMode = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.dark(
    primary: _primaryColor,
    onPrimary: Colors.black,
    secondary: _secondaryColor,
    onSecondary: Colors.black,
    tertiary: const Color(0xFF9E9E9E),
    surface: const Color(0xFF1E1E1E),
    onSurface: const Color(0xFFE8E8E8),
    error: const Color(0xFFEF5350),
    onError: Colors.black,
    outline: const Color(0xFF424242),
    outlineVariant: const Color(0xFF2A2A2A),
  ),
  scaffoldBackgroundColor: const Color(0xFF080808),
  appBarTheme: AppBarTheme(
    backgroundColor: Color(0xFF080808),
    foregroundColor: Colors.white,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    surfaceTintColor: Colors.transparent,
  ),
  cardTheme: CardThemeData(
    color: const Color(0xFF1A1A1A),
    elevation: 10,
    shadowColor: Colors.black,
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _primaryColor,
      foregroundColor: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      minimumSize: const Size(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: _primaryColor,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      minimumSize: const Size(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: BorderSide(color: _primaryColor.withValues(alpha: 0.8), width: 1.5),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: _primaryColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      minimumSize: const Size(0, 48),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: _secondaryColor,
    foregroundColor: Colors.black,
    elevation: 4,
    shape: CircleBorder(),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF2A2A2A),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF424242)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFF424242)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: _primaryColor, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFEF5350), width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFEF5350), width: 2),
    ),
    labelStyle: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 16),
    hintStyle: const TextStyle(color: Color(0xFF757575), fontSize: 16),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Color(0xFF1E1E1E),
    selectedItemColor: _primaryColor,
    unselectedItemColor: Color(0xFF757575),
    elevation: 8,
    type: BottomNavigationBarType.fixed,
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: const Color(0xFF1E1E1E),
    indicatorColor: _primaryColor.withValues(alpha: 0.15),
    surfaceTintColor: Colors.transparent,
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _primaryColor);
      }
      return const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xFF9E9E9E));
    }),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const IconThemeData(color: _primaryColor, size: 24);
      }
      return const IconThemeData(color: Color(0xFF757575), size: 24);
    }),
    height: 72,
  ),
  chipTheme: ChipThemeData(
    backgroundColor: const Color(0xFF2A2A2A),
    selectedColor: _primaryColor,
    labelStyle: const TextStyle(fontSize: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: const Color(0xFF252525),
    elevation: 24,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    titleTextStyle: GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: const Color(0xFFE8E8E8),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: const Color(0xFFE8E8E8),
    contentTextStyle: GoogleFonts.inter(
      fontSize: 14,
      color: Colors.black,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    behavior: SnackBarBehavior.floating,
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: Color(0xFF1E1E1E),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    elevation: 16,
  ),
  dividerTheme: const DividerThemeData(
    color: Color(0xFF424242),
    thickness: 1,
    space: 1,
  ),
  listTileTheme: const ListTileThemeData(
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    minVerticalPadding: 8,
  ),
  textTheme: _buildTextTheme(Brightness.dark),
);

TextTheme _buildTextTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final baseColor = isDark ? const Color(0xFFE8E8E8) : const Color(0xFF1A1A1A);
  final secondaryColor = isDark ? const Color(0xFFA0A0A0) : const Color(0xFF616161);

  return GoogleFonts.interTextTheme().copyWith(
    displayLarge: TextStyle(fontSize: 36, fontWeight: FontWeight.w700, color: baseColor, height: 1.2),
    displayMedium: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: baseColor, height: 1.25),
    displaySmall: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: baseColor, height: 1.3),
    headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: baseColor, height: 1.3),
    headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: baseColor, height: 1.35),
    headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: baseColor, height: 1.4),
    titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: baseColor, height: 1.4),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: baseColor, height: 1.4),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: baseColor, height: 1.4),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, color: baseColor, height: 1.5),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: secondaryColor, height: 1.5),
    bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: secondaryColor, height: 1.5),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: baseColor, height: 1.4),
    labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: baseColor, height: 1.4),
    labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: secondaryColor, height: 1.4),
  );
}
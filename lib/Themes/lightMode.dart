import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Healthcare clinic color palette based on research
// Primary Blue for trust (#1565C0), Secondary Green for health (#388E3C)
const Color _primaryColor = Color(0xFF1565C0);
const Color _secondaryColor = Color(0xFF388E3C);

ThemeData clinicLightTheme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.light(
    primary: _primaryColor,
    onPrimary: Colors.white,
    secondary: _secondaryColor,
    onSecondary: Colors.white,
    tertiary: const Color(0xFF757575),
    surface: Colors.white,
    onSurface: const Color(0xFF1A1A1A),
    error: const Color(0xFFD32F2F),
    onError: Colors.white,
    outline: const Color(0xFFE0E0E0),
    outlineVariant: const Color(0xFFF0F0F0),
  ),
  scaffoldBackgroundColor: const Color(0xFFEEEEEE),
  appBarTheme: AppBarTheme(
    backgroundColor: Color(0xFFEEEEEE),
    foregroundColor: _primaryColor,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: true,
    surfaceTintColor: Colors.transparent,
  ),
  cardTheme: CardThemeData(
    color: const Color(0xFFFAFAFA),
    elevation: 10,
    shadowColor: Colors.black45,
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _primaryColor,
      foregroundColor: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      minimumSize: const Size(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: _primaryColor,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      minimumSize: const Size(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: const BorderSide(color: _primaryColor, width: 1.5),
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
    foregroundColor: Colors.white,
    elevation: 4,
    shape: CircleBorder(),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _primaryColor, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 2),
    ),
    labelStyle: const TextStyle(color: Color(0xFF616161), fontSize: 16),
    hintStyle: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 16),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Colors.white,
    selectedItemColor: _primaryColor,
    unselectedItemColor: Color(0xFF9E9E9E),
    elevation: 8,
    type: BottomNavigationBarType.fixed,
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: _primaryColor.withValues(alpha: 0.1),
    surfaceTintColor: Colors.transparent,
    labelTextStyle: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _primaryColor);
      }
      return const TextStyle(fontSize: 12, fontWeight: FontWeight.w400, color: Color(0xFF616161));
    }),
    iconTheme: WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.selected)) {
        return const IconThemeData(color: _primaryColor, size: 24);
      }
      return const IconThemeData(color: Color(0xFF9E9E9E), size: 24);
    }),
    height: 72,
  ),
  chipTheme: ChipThemeData(
    backgroundColor: const Color(0xFFF5F5F5),
    selectedColor: _primaryColor,
    labelStyle: const TextStyle(fontSize: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: Colors.white,
    elevation: 24,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    titleTextStyle: GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: const Color(0xFF1A1A1A),
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    backgroundColor: const Color(0xFF323232),
    contentTextStyle: GoogleFonts.inter(
      fontSize: 14,
      color: Colors.white,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    behavior: SnackBarBehavior.floating,
  ),
  bottomSheetTheme: const BottomSheetThemeData(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    elevation: 16,
  ),
  dividerTheme: const DividerThemeData(
    color: Color(0xFFE0E0E0),
    thickness: 1,
    space: 1,
  ),
  listTileTheme: const ListTileThemeData(
    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    minVerticalPadding: 8,
  ),
  textTheme: _buildTextTheme(Brightness.light),
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
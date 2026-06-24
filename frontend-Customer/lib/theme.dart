import 'package:flutter/material.dart';

class AppTheme {
  static const primaryBlue = Color(0xFF2563EB);
  static const darkBlue = Color(0xFF111111);
  static const lightBlue = Color(0xFFEAF2FF);
  static const successGreen = Color(0xFF22C55E);
  static const dangerRed = Color(0xFFEF4444);

  static ThemeData theme = ThemeData(
    scaffoldBackgroundColor: Colors.black,
    primaryColor: primaryBlue,
    appBarTheme: const AppBarTheme(
      backgroundColor: darkBlue,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
  );
}

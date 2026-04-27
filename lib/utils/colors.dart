import 'package:flutter/material.dart';

class AppColors {
  // Brand Colors - Changed from Teal to Blue for medical/health app
  static const Color primary = Color.fromARGB(255, 33, 150, 243); // Blue
  static const Color scaffoldBackground = Color(0xFFF2F2F2);
  static const Color surface = Colors.white;

  // Text Colors
  static const Color textPrimary = Color(0xFF1E1E1E);
  static const Color textSecondary = Color(0xFF424242);

  // Status Colors
  static const Color error = Color(0xFFB00020);
  static const Color success = Color(0xFF4CAF50); // Changed from WhatsApp green
  static const Color info = Colors.blue;
  static const Color warning = Colors.orange;

  // Third Party Colors - Removed WhatsApp green reference
  static const Color whatsappGreen = Color(0xFF25D366);
}

import 'package:flutter/material.dart';

class ChildTheme {
  static const Color primaryBlue = Color(0xFF2563EB); // Clean Blue
  static const Color background = Color(0xFFF8FAFC);  // Light Gray
  static const Color surface = Colors.white;          // White cards
  static const Color textPrimary = Color(0xFF1E293B); // Dark Slate
  static const Color textSecondary = Color(0xFF64748B);
  static const Color sosRed = Color(0xFFEF4444);
  static const Color safeGreen = Color(0xFF10B981);
  static const Color purpleAcc = Color(0xFF8B5CF6);
  static const Color borderLight = Color(0xFFE2E8F0);

  // Standard Opaque Card Decoration
  static final BoxDecoration cardDecoration = BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: borderLight),
    boxShadow: [
      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
    ],
  );

  // Re-routes the previous applyGlass syntax to just return a normal opaque card.
  static Widget applyGlass({required Widget child, bool usePadding = true}) {
    return Container(
      padding: usePadding ? const EdgeInsets.all(16) : null,
      decoration: cardDecoration,
      child: child,
    );
  }

  static final TextStyle titleStyle = const TextStyle(
    color: textPrimary,
    fontSize: 24,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
  );

  static final TextStyle subtitleStyle = const TextStyle(
    color: textSecondary,
    fontSize: 14,
    fontWeight: FontWeight.w500,
  );
}

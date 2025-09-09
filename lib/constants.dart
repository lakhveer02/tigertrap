import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum BoardType { square, aaduPuli }
enum Difficulty { easy, medium, hard }

class AppColors {
  static const Color deepSpace = Color(0xFF1A1D24);
  static const Color cosmicBlue = Color(0xFF2A2F3D);
  static const Color stellarGold = Color(0xFFFFD700);
  static const Color nebulaTeal = Color(0xFF4ECDC4);
  static const Color darkMatter = Color(0xFF121212);
  static const Color starDust = Color(0xFFBDBDBD);
  static const Color supernova = Color(0xFFFF6B6B);
  static const Color jungleGreen = Color(0xFF2D5A27);

  static const Gradient spaceGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [deepSpace, cosmicBlue],
  );

  static BoxDecoration get panelDecoration => BoxDecoration(
    gradient: const LinearGradient(
      colors: [cosmicBlue, Color(0xFF363D4E)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(20),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withAlpha((0.4 * 255).toInt()),
        blurRadius: 15,
        offset: Offset(0, 6),
      ),
    ],
    border: Border.all(color: stellarGold.withAlpha((0.2 * 255).toInt())),
  );
}

class AppTextStyles {
  static TextStyle cosmicTitle(BuildContext context) {
    return GoogleFonts.orbitron(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      foreground:
          Paint()
            ..shader = const LinearGradient(
              colors: [AppColors.stellarGold, AppColors.nebulaTeal],
            ).createShader(const Rect.fromLTWH(0, 0, 200, 70)),
      letterSpacing: 2,
    );
  }

  static TextStyle nebulaSubtitle(BuildContext context) {
    return GoogleFonts.rajdhani(
      fontSize: 20,
      fontWeight: FontWeight.w600,
    color: AppColors.starDust,
      shadows: [
        Shadow(
          color: AppColors.stellarGold.withAlpha((0.5 * 255).toInt()),
          offset: const Offset(0, 2),
          blurRadius: 4,
        ),
      ],
    );
  }


  static TextStyle starText(BuildContext context) {
    return GoogleFonts.spaceMono(
      fontSize: 16,
      color: Colors.white,
      fontWeight: FontWeight.w500,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Tipografía OVUM: **Sora** para títulos/display (geométrica, distintiva)
/// e **Inter** para cuerpo y labels de UI.
abstract final class AppTypography {
  static TextTheme build(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? Typography.material2021().white
        : Typography.material2021().black;

    final sora = GoogleFonts.soraTextTheme(base);
    final inter = GoogleFonts.interTextTheme(base);

    return inter.copyWith(
      displayLarge: sora.displayLarge?.copyWith(fontWeight: FontWeight.w700),
      displayMedium: sora.displayMedium?.copyWith(fontWeight: FontWeight.w700),
      displaySmall: sora.displaySmall?.copyWith(fontWeight: FontWeight.w700),
      headlineLarge: sora.headlineLarge?.copyWith(fontWeight: FontWeight.w700),
      headlineMedium: sora.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
      headlineSmall: sora.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
      titleLarge: sora.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

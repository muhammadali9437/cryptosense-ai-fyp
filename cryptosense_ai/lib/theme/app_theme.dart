
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Three text roles used everywhere:
/// display = Sora (headings, Sage's market read), body = DM Sans,
/// number = DM Sans with tabular figures so prices don't jiggle as they update.
class AppText {
  AppText._();

  static TextStyle display(double size,
          {Color color = AppColors.text, FontWeight w = FontWeight.w600}) =>
      GoogleFonts.sora(
          fontSize: size, fontWeight: w, color: color, height: 1.25, letterSpacing: -0.2);

  static TextStyle body(double size,
          {Color color = AppColors.text, FontWeight w = FontWeight.w400, double height = 1.45}) =>
      GoogleFonts.dmSans(fontSize: size, fontWeight: w, color: color, height: height);

  static TextStyle number(double size,
          {Color color = AppColors.text, FontWeight w = FontWeight.w600}) =>
      GoogleFonts.dmSans(
        fontSize: size,
        fontWeight: w,
        color: color,
        height: 1.3,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}

class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    final base = ThemeData(brightness: Brightness.dark, useMaterial3: true);
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: c),
        );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.ink,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.brass,
        onPrimary: AppColors.ink,
        secondary: AppColors.bull,
        surface: AppColors.panel,
        onSurface: AppColors.text,
        error: AppColors.bear,
      ),
      textTheme: GoogleFonts.dmSansTextTheme(base.textTheme)
          .apply(bodyColor: AppColors.text, displayColor: AppColors.text),
      dividerColor: AppColors.line,
      iconTheme: const IconThemeData(color: AppColors.muted),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.brass,
        selectionColor: AppColors.brass.fade(.3),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.ink,
        hintStyle: AppText.body(14, color: AppColors.faint),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: border(AppColors.line),
        enabledBorder: border(AppColors.line),
        focusedBorder: border(AppColors.brass),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 4,
        activeTrackColor: AppColors.brass,
        inactiveTrackColor: AppColors.line,
        thumbColor: AppColors.brass,
        overlayColor: AppColors.brass.fade(.15),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.panelHi,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.line),
        ),
        textStyle: AppText.body(12.5),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.brass),
      drawerTheme: const DrawerThemeData(backgroundColor: AppColors.sidebar),
      scrollbarTheme: const ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(AppColors.line),
        radius: Radius.circular(8),
      ),
    );
  }
}

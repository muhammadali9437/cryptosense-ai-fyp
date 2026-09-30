import 'package:flutter/material.dart';

/// The CryptoSense palette: deep plum "night trading desk" with a brass accent.
/// Bull (mint) and bear (coral) are reserved for price direction only.
class AppColors {
  AppColors._();

  static const ink = Color(0xFF120E1A); // page background
  static const sidebar = Color(0xFF0E0A15); // navigation rail
  static const panel = Color(0xFF1B1526); // cards and panels
  static const panelHi = Color(0xFF261D35); // hover / raised surfaces
  static const line = Color(0xFF30263F); // borders and grid lines

  static const text = Color(0xFFF1ECF7);
  static const muted = Color(0xFFA398B8);
  static const faint = Color(0xFF706688);

  static const brass = Color(0xFFE3B55B); // brand accent
  static const orchid = Color(0xFF9C6ADE); // second brand tone (Sage)
  static const bull = Color(0xFF5FD4A0); // price up
  static const bear = Color(0xFFF2706B); // price down
  static const calm = Color(0xFF8FB3FF); // neutral / info
  static const warn = Color(0xFFF0A04B); // caution
}

extension Fade on Color {
  /// Same color with a new opacity (0..1). Works on every Flutter 3.x version.
  Color fade(double opacity) => withAlpha((opacity.clamp(0.0, 1.0) * 255).round());
}

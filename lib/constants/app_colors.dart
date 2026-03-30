import 'package:flutter/material.dart';

/// Paleta de colores centralizada de Match Point.
/// Usar estas constantes en lugar de literales `Color(0xFF...)` dispersos.
abstract class AppColors {
  // ── Marca principal ────────────────────────────────────────────────────────
  /// Verde lima / acento primario — botones, highlights, ELO
  static const lime       = Color(0xFFCCFF00);
  /// Verde oscuro profundo — fondo de scaffolds
  static const deepGreen  = Color(0xFF0A1F1A);
  /// Verde oscuro más profundo — backgrounds alternativos
  static const deeperGreen = Color(0xFF0B2218);
  /// Verde aplicación — cards, AppBar, containers
  static const appGreen   = Color(0xFF1A3A34);
  /// Verde aplicación más claro — drawers, bottom sheets
  static const appGreenLight = Color(0xFF2C4A44);
  /// Negro verdoso — navigation bar, fondo de bracket
  static const darkBg     = Color(0xFF060F0C);
  /// Fondo oscuro alternativo — dialogs, modals
  static const modalBg    = Color(0xFF0D1F1A);

  // ── Estados / semánticos ────────────────────────────────────────────────────
  static const success    = Color(0xFF1A4D32);
  static const error      = Color(0xFFFF6B6B);
  static const warning    = Colors.orangeAccent;
  static const info       = Colors.blueAccent;

  // ── Torneo / estados ────────────────────────────────────────────────────────
  static const statusOpen        = Colors.orangeAccent;
  static const statusInProgress  = Colors.greenAccent;
  static const statusFinished    = Colors.white38;
  static const statusSoon        = Colors.blueAccent;

  // ── Texto ───────────────────────────────────────────────────────────────────
  static const textPrimary   = Colors.white;
  static const textSecondary = Colors.white70;
  static const textDisabled  = Colors.white38;
  static const textHint      = Colors.white24;

  // ── Bordes / separadores ────────────────────────────────────────────────────
  static const border        = Color(0x14FFFFFF); // white.withOpacity(0.08)
  static const borderLight   = Color(0x1FFFFFFF); // white.withOpacity(0.12)

  // ── Helpers privados — no usar directamente ─────────────────────────────────
  static Color limeWithAlpha(double opacity) => lime.withOpacity(opacity);
  static Color whiteWithAlpha(double opacity) => Colors.white.withOpacity(opacity);
}

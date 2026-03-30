import 'package:flutter/material.dart';

/// Paleta de colores que cambia según el tema (oscuro/claro).
/// Uso: `final c = TC.of(context);`
class TC {
  final bool dark;
  const TC._(this.dark);

  factory TC.of(BuildContext context) =>
      TC._(Theme.of(context).brightness == Brightness.dark);

  // ── Fondos principales ────────────────────────────────────────────────────
  Color get scaffold  => dark ? const Color(0xFF0A1F1A) : const Color(0xFFF2F5F2);
  Color get scaffold2 => dark ? const Color(0xFF0B2218) : const Color(0xFFE8ECE8);
  Color get navBg     => dark ? const Color(0xFF060F0C) : Colors.white;
  Color get surface   => dark ? const Color(0xFF1A3A34) : Colors.white;
  Color get surface2  => dark ? const Color(0xFF2C4A44) : const Color(0xFFF0F4F0);
  Color get modal     => dark ? const Color(0xFF0D1F1A) : const Color(0xFFF8F8F8);
  Color get heroGrad1 => dark ? const Color(0xFF0B2218) : const Color(0xFF1A3A34);
  Color get heroGrad2 => dark ? const Color(0xFF0F2D22) : const Color(0xFF2D6A4F);

  // ── Texto ─────────────────────────────────────────────────────────────────
  Color get text       => dark ? Colors.white          : const Color(0xFF0B2218);
  Color get text70     => dark ? Colors.white70        : Colors.black87;
  Color get text54     => dark ? Colors.white54        : Colors.black54;
  Color get text38     => dark ? Colors.white38        : Colors.black45;
  Color get text24     => dark ? Colors.white24        : Colors.black38;
  Color get text12     => dark ? Colors.white12        : Colors.black12;

  // ── Superficies con opacidad (overlay semitransparente) ───────────────────
  Color overlay(double op) =>
      dark ? Colors.white.withValues(alpha: op) : Colors.black.withValues(alpha: op * 0.55);

  Color border([double op = 0.08]) =>
      dark ? Colors.white.withValues(alpha: op) : Colors.black.withValues(alpha: op * 0.7);

  // ── Nav bar íconos ────────────────────────────────────────────────────────
  Color get navUnselected => dark ? Colors.white24 : Colors.black38;
  Color get navBorder =>
      dark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.08);

  // ── Acento (lima) — mismo en ambos modos ──────────────────────────────────
  static const lime = Color(0xFFCCFF00);
}

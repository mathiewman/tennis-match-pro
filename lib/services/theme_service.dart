import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gestiona el ThemeMode de la app y lo persiste en SharedPreferences.
/// Uso: ThemeService.instance.mode (ValueNotifier) para leer/escribir.
class ThemeService {
  ThemeService._();
  static final ThemeService instance = ThemeService._();

  static const _key = 'app_theme_mode';

  final ValueNotifier<ThemeMode> mode =
      ValueNotifier<ThemeMode>(ThemeMode.dark);

  /// Llama esto al arrancar la app (antes de runApp).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == 'light') {
      mode.value = ThemeMode.light;
    } else {
      mode.value = ThemeMode.dark;
    }
  }

  Future<void> setDark() async {
    mode.value = ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, 'dark');
  }

  Future<void> setLight() async {
    mode.value = ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, 'light');
  }

  bool get isDark => mode.value == ThemeMode.dark;
}

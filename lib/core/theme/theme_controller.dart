import 'package:flutter/material.dart';

class ThemeController extends ChangeNotifier {
  ThemeController({
    ThemeMode initialMode = ThemeMode.light,
  }) : _themeMode = initialMode;

  ThemeMode _themeMode;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void setLightMode() {
    if (_themeMode == ThemeMode.light) {
      return;
    }

    _themeMode = ThemeMode.light;
    notifyListeners();
  }

  void setDarkMode() {
    if (_themeMode == ThemeMode.dark) {
      return;
    }

    _themeMode = ThemeMode.dark;
    notifyListeners();
  }

  void toggleTheme() {
    _themeMode =
        _themeMode == ThemeMode.dark
            ? ThemeMode.light
            : ThemeMode.dark;

    notifyListeners();
  }
}
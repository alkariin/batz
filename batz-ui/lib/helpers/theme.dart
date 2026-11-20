import 'package:flutter/material.dart';

/// The single accent colour of the app (specification, 4.6).
const accentColor = Color(0xFF2E7D5B);

/// Material 3 theme for [brightness]; the app follows the device setting.
ThemeData buildTheme(Brightness brightness) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: accentColor, brightness: brightness),
  );
}

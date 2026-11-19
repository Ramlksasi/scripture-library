import 'package:material_ui/material_ui.dart';

const paper = Color(0xFFF7F4EB);
const ink = Color(0xFF243630);
const muted = Color(0xFF5C6A61);
const accent = Color(0xFF315447);
const line = Color(0xFFE2DCCD);
const gold = Color(0xFFE8CC91);
const serif = 'Library Serif';

ThemeData libraryTheme() {
  final colors = ColorScheme.fromSeed(
    seedColor: accent,
    primary: accent,
    surface: paper,
    onSurface: ink,
  );
  return ThemeData(
    colorScheme: colors,
    scaffoldBackgroundColor: paper,
    useMaterial3: true,
    appBarTheme: const AppBarTheme(
      backgroundColor: paper,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    dividerColor: line,
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFFFFCF4),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: line),
      ),
    ),
  );
}

import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFFF7FBF6);
  static const Color backgroundSoft = Color(0xFFEAF6EA);
  static const Color card = Color(0xF7FFFFFF);
  static const Color cardSolid = Color(0xFFFFFFFF);
  static const Color inputFill = Color(0xFFFFFFFF);
  static const Color border = Color(0x2414532D);
  static const Color accent = Color(0xFF16A34A);
  static const Color accentDark = Color(0xFF15803D);
  static const Color secondary = Color(0xFF0F766E);
  static const Color text = Color(0xFF102015);
  static const Color softText = Color(0xFF617468);
  static const Color success = Color(0xFF22C55E);
  static const Color danger = Color(0xFFDC2626);
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: AppColors.background,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.accent,
          secondary: AppColors.secondary,
          surface: AppColors.cardSolid,
          onSurface: AppColors.text,
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: AppColors.text,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: AppColors.text,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.text,
      contentTextStyle: const TextStyle(color: Colors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.accent),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: mainButtonStyle()),
  );
}

Widget appLogo({double size = 72}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.accent, Color(0xFF86EFAC)],
      ),
      borderRadius: BorderRadius.circular(size * 0.33),
      border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
      boxShadow: [
        BoxShadow(
          color: AppColors.accent.withValues(alpha: 0.22),
          blurRadius: 30,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    child: Icon(Icons.eco_rounded, color: Colors.white, size: size * 0.5),
  );
}

ButtonStyle mainButtonStyle() {
  return ElevatedButton.styleFrom(
    backgroundColor: AppColors.accent,
    foregroundColor: Colors.white,
    disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.28),
    disabledForegroundColor: Colors.white.withValues(alpha: 0.72),
    elevation: 8,
    shadowColor: AppColors.accent.withValues(alpha: 0.20),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
  );
}

InputDecoration baseInputDecoration({
  required String label,
  required String hint,
  required IconData icon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: AppColors.inputFill,
    labelStyle: const TextStyle(color: AppColors.softText),
    hintStyle: TextStyle(color: AppColors.softText.withValues(alpha: 0.68)),
    prefixIconColor: AppColors.secondary,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.accent, width: 1.4),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.danger),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: const BorderSide(color: AppColors.danger),
    ),
  );
}

InputDecoration authPasswordDecoration({
  required String label,
  required String hint,
  required bool isHidden,
  required VoidCallback onPressed,
}) {
  return baseInputDecoration(
    label: label,
    hint: hint,
    icon: Icons.lock_outline,
  ).copyWith(
    suffixIcon: IconButton(
      onPressed: onPressed,
      icon: Icon(
        isHidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
    ),
    suffixIconColor: AppColors.softText,
  );
}

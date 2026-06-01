import 'package:flutter/material.dart';

enum AppThemeChoice {
  light,
  dark;

  String get firestoreValue => this == AppThemeChoice.dark ? "dark" : "light";

  static AppThemeChoice fromValue(Object? value) {
    return value == "light" ? AppThemeChoice.light : AppThemeChoice.dark;
  }
}

final ValueNotifier<AppThemeChoice> appThemeController =
    ValueNotifier<AppThemeChoice>(AppThemeChoice.dark);

class _AppColorPalette {
  final Color background;
  final Color backgroundSoft;
  final Color card;
  final Color cardSolid;
  final Color inputFill;
  final Color border;
  final Color accent;
  final Color accentDark;
  final Color secondary;
  final Color violet;
  final Color violetDark;
  final Color text;
  final Color softText;
  final Color success;
  final Color danger;
  final Brightness brightness;

  const _AppColorPalette({
    required this.background,
    required this.backgroundSoft,
    required this.card,
    required this.cardSolid,
    required this.inputFill,
    required this.border,
    required this.accent,
    required this.accentDark,
    required this.secondary,
    required this.violet,
    required this.violetDark,
    required this.text,
    required this.softText,
    required this.success,
    required this.danger,
    required this.brightness,
  });
}

class AppColors {
  static const _light = _AppColorPalette(
    background: Color(0xFFFFF4F8),
    backgroundSoft: Color(0xFFFFE4EF),
    card: Color(0xFAFFFFFF),
    cardSolid: Color(0xFFFFFFFF),
    inputFill: Color(0xFFFFF8FB),
    border: Color(0x2B8A1E4D),
    accent: Color(0xFFF30A68),
    accentDark: Color(0xFFC80755),
    secondary: Color(0xFFFF4D93),
    violet: Color(0xFF8A1E4D),
    violetDark: Color(0xFF211020),
    text: Color(0xFF24111F),
    softText: Color(0xFF7A6575),
    success: Color(0xFF22C55E),
    danger: Color(0xFFE11D48),
    brightness: Brightness.light,
  );

  static const _dark = _AppColorPalette(
    background: Color(0xFF120D1A),
    backgroundSoft: Color(0xFF211020),
    card: Color(0xF22A2333),
    cardSolid: Color(0xFF34283D),
    inputFill: Color(0xFF211B2B),
    border: Color(0x66433246),
    accent: Color(0xFFF30A68),
    accentDark: Color(0xFFC80755),
    secondary: Color(0xFFFF4D93),
    violet: Color(0xFF8A1E4D),
    violetDark: Color(0xFF171824),
    text: Color(0xFFF7EAF1),
    softText: Color(0xFFA99AAA),
    success: Color(0xFF35D978),
    danger: Color(0xFFFF5C8A),
    brightness: Brightness.dark,
  );

  static _AppColorPalette get _palette =>
      appThemeController.value == AppThemeChoice.dark ? _dark : _light;

  static bool get isDark => _palette.brightness == Brightness.dark;
  static Color get background => _palette.background;
  static Color get backgroundSoft => _palette.backgroundSoft;
  static Color get card => _palette.card;
  static Color get cardSolid => _palette.cardSolid;
  static Color get inputFill => _palette.inputFill;
  static Color get border => _palette.border;
  static Color get accent => _palette.accent;
  static Color get accentDark => _palette.accentDark;
  static Color get secondary => _palette.secondary;
  static Color get violet => _palette.violet;
  static Color get violetDark => _palette.violetDark;
  static Color get text => _palette.text;
  static Color get softText => _palette.softText;
  static Color get success => _palette.success;
  static Color get danger => _palette.danger;
}

ThemeData buildAppTheme([AppThemeChoice? choice]) {
  final palette = choice == AppThemeChoice.dark
      ? AppColors._dark
      : AppColors._light;

  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: palette.background,
    colorScheme:
        ColorScheme.fromSeed(
          seedColor: palette.accent,
          brightness: palette.brightness,
        ).copyWith(
          primary: palette.accent,
          secondary: palette.secondary,
          tertiary: palette.violet,
          surface: palette.cardSolid,
          onSurface: palette.text,
        ),
    appBarTheme: AppBarTheme(
      backgroundColor: palette.brightness == Brightness.dark
          ? const Color(0xFF211020)
          : Colors.transparent,
      foregroundColor: palette.text,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: palette.text,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: palette.text,
      contentTextStyle: TextStyle(color: palette.background),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: palette.accent),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: mainButtonStyle()),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: palette.inputFill,
      iconColor: palette.secondary,
      prefixIconColor: palette.secondary,
      suffixIconColor: palette.softText,
      labelStyle: TextStyle(color: palette.softText),
      hintStyle: TextStyle(color: palette.softText.withValues(alpha: 0.68)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: palette.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: palette.accent, width: 1.4),
      ),
    ),
    cardTheme: CardThemeData(
      color: palette.card,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    dividerTheme: DividerThemeData(color: palette.border),
  );
}

Widget appLogo({double size = 72, Color? color}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * 0.23),
      border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
      boxShadow: [
        BoxShadow(
          color: AppColors.accent.withValues(alpha: 0.26),
          blurRadius: size * 0.34,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: RepaintBoundary(
      child: CustomPaint(
        painter: _FildirIconPainter(avatarColor: color),
        child: SizedBox.square(dimension: size),
      ),
    ),
  );
}

class _FildirIconPainter extends CustomPainter {
  final Color? avatarColor;

  const _FildirIconPainter({required this.avatarColor});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final rect = Offset.zero & Size(s, s);
    final radius = Radius.circular(s * 0.23);
    final rrect = RRect.fromRectAndRadius(rect, radius);
    final rightMaskColor = avatarColor ?? AppColors.secondary;
    final leftMaskColor = avatarColor == null
        ? AppColors.violet
        : Color.lerp(AppColors.violet, avatarColor, 0.16)!;

    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.secondary, AppColors.accentDark],
        ).createShader(rect),
    );

    canvas.save();
    canvas.clipRRect(rrect);

    final leftMask = Path()
      ..moveTo(-s * 0.10, s * 0.18)
      ..lineTo(s * 0.05, s * 0.20)
      ..cubicTo(s * 0.19, s * 0.24, s * 0.35, s * 0.24, s * 0.46, s * 0.39)
      ..lineTo(s * 0.52, s * 0.53)
      ..cubicTo(s * 0.39, s * 0.61, s * 0.25, s * 0.59, s * 0.12, s * 0.73)
      ..lineTo(-s * 0.08, s * 0.89)
      ..close();

    canvas.drawPath(
      leftMask,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [leftMaskColor, AppColors.violetDark],
        ).createShader(rect),
    );

    final rightMask = Path()
      ..moveTo(s * 0.48, s * 0.47)
      ..cubicTo(s * 0.56, s * 0.35, s * 0.67, s * 0.28, s * 1.08, s * 0.18)
      ..lineTo(s * 1.08, s * 0.83)
      ..cubicTo(s * 0.86, s * 0.80, s * 0.75, s * 0.83, s * 0.61, s * 0.68)
      ..cubicTo(s * 0.55, s * 0.63, s * 0.49, s * 0.59, s * 0.43, s * 0.58)
      ..close();

    canvas.drawPath(
      rightMask,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color.lerp(rightMaskColor, Colors.white, 0.06)!,
            rightMaskColor,
          ],
        ).createShader(rect),
    );

    final overlap = Path()
      ..moveTo(s * 0.43, s * 0.37)
      ..cubicTo(s * 0.51, s * 0.47, s * 0.56, s * 0.55, s * 0.54, s * 0.69)
      ..cubicTo(s * 0.46, s * 0.65, s * 0.40, s * 0.56, s * 0.39, s * 0.47)
      ..close();

    canvas.drawPath(
      overlap,
      Paint()..color = AppColors.violetDark.withValues(alpha: 0.78),
    );

    final tearPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.032
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final topTear = Path()
      ..moveTo(s * 0.05, s * 0.20)
      ..cubicTo(s * 0.20, s * 0.23, s * 0.33, s * 0.25, s * 0.43, s * 0.36)
      ..cubicTo(s * 0.50, s * 0.43, s * 0.51, s * 0.48, s * 0.54, s * 0.53)
      ..cubicTo(s * 0.66, s * 0.40, s * 0.73, s * 0.33, s * 0.92, s * 0.30);
    canvas.drawPath(topTear, tearPaint);

    final leftEye = Path()
      ..moveTo(s * 0.11, s * 0.61)
      ..cubicTo(s * 0.20, s * 0.50, s * 0.30, s * 0.47, s * 0.43, s * 0.55)
      ..cubicTo(s * 0.34, s * 0.71, s * 0.24, s * 0.77, s * 0.10, s * 0.76)
      ..close();
    canvas.drawPath(leftEye, Paint()..color = Colors.white);

    final leftIris = Path()
      ..moveTo(s * 0.30, s * 0.57)
      ..quadraticBezierTo(s * 0.36, s * 0.62, s * 0.27, s * 0.72)
      ..quadraticBezierTo(s * 0.22, s * 0.65, s * 0.30, s * 0.57)
      ..close();
    canvas.drawPath(leftIris, Paint()..color = AppColors.accentDark);

    final rightEye = Path()
      ..moveTo(s * 0.66, s * 0.57)
      ..cubicTo(s * 0.78, s * 0.47, s * 0.88, s * 0.49, s * 0.98, s * 0.57)
      ..cubicTo(s * 0.88, s * 0.70, s * 0.78, s * 0.76, s * 0.62, s * 0.73)
      ..close();
    canvas.drawPath(rightEye, Paint()..color = Colors.white);

    final rightIris = Path()
      ..moveTo(s * 0.80, s * 0.58)
      ..quadraticBezierTo(s * 0.73, s * 0.65, s * 0.84, s * 0.72)
      ..quadraticBezierTo(s * 0.90, s * 0.65, s * 0.80, s * 0.58)
      ..close();
    canvas.drawPath(rightIris, Paint()..color = AppColors.accentDark);

    final whiteSpecklePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.62);
    final darkSpecklePaint = Paint()
      ..color = AppColors.violetDark.withValues(alpha: 0.38);

    for (var i = 0; i < 64; i++) {
      final x = (((i * 37) + 11) % 100) / 100 * s;
      final y = (((i * 53) + 19) % 100) / 100 * s;
      final isInMaskArea = x < s * 0.52 || (x > s * 0.46 && y > s * 0.28);
      if (!isInMaskArea) {
        continue;
      }

      canvas.drawCircle(
        Offset(x, y),
        s * (i.isEven ? 0.0055 : 0.0035),
        i % 3 == 0 ? darkSpecklePaint : whiteSpecklePaint,
      );
    }

    canvas.restore();

    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.018
        ..color = Colors.white.withValues(alpha: 0.42),
    );
  }

  @override
  bool shouldRepaint(covariant _FildirIconPainter oldDelegate) {
    return oldDelegate.avatarColor != avatarColor;
  }
}

ButtonStyle mainButtonStyle() {
  return ElevatedButton.styleFrom(
    backgroundColor: AppColors.accent,
    foregroundColor: Colors.white,
    disabledBackgroundColor: AppColors.accent.withValues(alpha: 0.28),
    disabledForegroundColor: Colors.white.withValues(alpha: 0.72),
    elevation: 10,
    shadowColor: AppColors.accent.withValues(alpha: 0.34),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
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
    labelStyle: TextStyle(color: AppColors.softText),
    hintStyle: TextStyle(color: AppColors.softText.withValues(alpha: 0.68)),
    prefixIconColor: AppColors.secondary,
    suffixIconColor: AppColors.softText,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: AppColors.border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: AppColors.accent, width: 1.4),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: AppColors.danger),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide(color: AppColors.danger),
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

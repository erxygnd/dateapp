import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFFFFF7F1);
  static const Color backgroundSoft = Color(0xFFFFE7D7);
  static const Color card = Color(0xFAFFFFFF);
  static const Color cardSolid = Color(0xFFFFFFFF);
  static const Color inputFill = Color(0xFFFFFBF7);
  static const Color border = Color(0x2B4B1F6F);
  static const Color accent = Color(0xFFFF5A1F);
  static const Color accentDark = Color(0xFFE44710);
  static const Color secondary = Color(0xFF23B64F);
  static const Color violet = Color(0xFF4B1F78);
  static const Color violetDark = Color(0xFF26113D);
  static const Color text = Color(0xFF211626);
  static const Color softText = Color(0xFF756571);
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
          tertiary: AppColors.violet,
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
        painter: _PiyasaIconPainter(avatarColor: color),
        child: SizedBox.square(dimension: size),
      ),
    ),
  );
}

class _PiyasaIconPainter extends CustomPainter {
  final Color? avatarColor;

  const _PiyasaIconPainter({required this.avatarColor});

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
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFF6A1F), AppColors.accentDark],
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
  bool shouldRepaint(covariant _PiyasaIconPainter oldDelegate) {
    return oldDelegate.avatarColor != avatarColor;
  }
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

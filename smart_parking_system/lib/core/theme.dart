import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';


class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
        PointerDeviceKind.unknown,
      };
}

class AppTheme {
  
  static const Color background = Color(0xFF07070F);
  static const Color surface = Color(0xFF12121F);
  static const Color surfaceLight = Color(0xFF1A1B2E);
  static const Color surfaceGlass = Color(0x14FFFFFF);

  static const Color accent = Color(0xFF00C2FF);        
  static const Color accentBlue = Color(0xFF3D7CFF);     
  static const Color accentDeepBlue = Color(0xFF2450E8);  
  static const Color accentSky = Color(0xFF6FE3FF);       
  static const Color accentGreen = Color(0xFF35F2A0);
  static const Color accentAmber = Color(0xFFFFC24B);
  static const Color accentRed = Color(0xFFFF4D6A);

  static const Color textPrimary = Color(0xFFF3F5FF);
  static const Color textSecondary = Color(0xFF9AA3C7);
  static const Color textMuted = Color(0xFF565B7A);
  static const Color border = Color(0x1EFFFFFF);

  
  static const Color statusFree = accentGreen;
  static const Color statusMedium = accentAmber;
  static const Color statusFull = accentRed;

  
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF00C2FF), Color(0xFF3D7CFF)],
  );

  static const LinearGradient auroraGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6FE3FF), Color(0xFF3D7CFF), Color(0xFF2450E8)],
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF07070F), Color(0xFF0B0C1A), Color(0xFF07070F)],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF35F2A0), Color(0xFF00C2A8)],
  );

  static const double radiusSm = 14;
  static const double radiusMd = 20;
  static const double radiusLg = 28;
  static const double radiusPill = 999;

  
  static ThemeData get darkTheme {
    final base = ThemeData(brightness: Brightness.dark);

    final headingFont = GoogleFonts.spaceGrotesk;
    final bodyFont = GoogleFonts.plusJakartaSans;

    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: accentBlue,
        surface: surface,
        error: accentRed,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      textTheme: TextTheme(
        displayLarge: headingFont(
          fontSize: 34, fontWeight: FontWeight.w700,
          color: textPrimary, letterSpacing: -1.2, height: 1.1,
        ),
        displayMedium: headingFont(
          fontSize: 26, fontWeight: FontWeight.w700,
          color: textPrimary, letterSpacing: -0.8, height: 1.15,
        ),
        headlineMedium: headingFont(
          fontSize: 20, fontWeight: FontWeight.w600,
          color: textPrimary, letterSpacing: -0.4,
        ),
        titleMedium: bodyFont(
          fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary,
        ),
        bodyLarge: bodyFont(
          fontSize: 15, color: textSecondary, height: 1.5,
        ),
        bodyMedium: bodyFont(
          fontSize: 13, color: textSecondary, height: 1.4,
        ),
        labelLarge: bodyFont(
          fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.3,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceGlass,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        hintStyle: bodyFont(color: textMuted, fontSize: 15),
        labelStyle: bodyFont(color: textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
          textStyle: bodyFont(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: headingFont(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: accent,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  
  static BoxDecoration glassDecoration({
    double radius = radiusMd,
    Color? borderColor,
    bool shadow = false,
  }) {
    return BoxDecoration(
      color: surfaceGlass,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: borderColor ?? border, width: 1),
      boxShadow: shadow
          ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ]
          : null,
    );
  }

  static List<BoxShadow> glowShadow(Color color, {double blur = 20, double opacity = 0.35}) {
    return [BoxShadow(color: color.withOpacity(opacity), blurRadius: blur, offset: const Offset(0, 8))];
  }

  
  static Color statusColor(double occupancy) {
    if (occupancy < 0.6) return statusFree;
    if (occupancy < 0.85) return statusMedium;
    return statusFull;
  }

  static String statusLabel(double occupancy) {
    if (occupancy < 0.6) return 'SLOBODNO';
    if (occupancy < 0.85) return 'POPUNJAVA SE';
    return 'SKORO PUNO';
  }
}

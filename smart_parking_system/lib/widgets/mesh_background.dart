import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme.dart';


class MeshBackground extends StatelessWidget {
  final Widget? child;
  const MeshBackground({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Stack(
      children: [
        Container(color: AppTheme.background),
        Positioned(
          top: -size.width * 0.35,
          left: -size.width * 0.25,
          child: _blob(size.width * 0.9, AppTheme.accentDeepBlue, 0.28),
        ),
        Positioned(
          top: size.height * 0.15,
          right: -size.width * 0.35,
          child: _blob(size.width * 0.8, AppTheme.accent, 0.22),
        ),
        Positioned(
          bottom: -size.width * 0.3,
          left: -size.width * 0.2,
          child: _blob(size.width * 0.75, AppTheme.accentSky, 0.16),
        ),
        if (child != null) child!,
      ],
    );
  }

  Widget _blob(double diameter, Color color, double opacity) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withOpacity(opacity),
        ),
      ),
    );
  }
}

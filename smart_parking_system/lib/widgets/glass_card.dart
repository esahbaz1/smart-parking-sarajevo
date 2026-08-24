import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/theme.dart';


class GlassCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final Color? tint;
  final double blur;
  final Gradient? borderGradient;
  final List<BoxShadow>? shadow;

  const GlassCard({
    super.key,
    required this.child,
    this.radius = AppTheme.radiusMd,
    this.padding,
    this.tint,
    this.blur = 18,
    this.borderGradient,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadow ??
            [
              BoxShadow(
                color: Colors.black.withOpacity(0.32),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: tint ?? Colors.white.withOpacity(0.06),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: Colors.white.withOpacity(0.14),
                width: 1,
              ),
              gradient: borderGradient == null
                  ? null
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.10),
                        Colors.white.withOpacity(0.02),
                      ],
                    ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../core/theme.dart';

class CustomButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final LinearGradient? gradient;
  final bool outlined;
  final IconData? icon;

  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.gradient,
    this.outlined = false,
    this.icon,
  });

  @override
  State<CustomButton> createState() => _CustomButtonState();
}

class _CustomButtonState extends State<CustomButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;
    final gradient = widget.gradient;

    return GestureDetector(
      onTap: isDisabled ? null : widget.onPressed,
      onTapDown: isDisabled ? null : (_) => setState(() => _scale = 0.97),
      onTapUp: isDisabled ? null : (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: AnimatedOpacity(
          opacity: isDisabled && !widget.isLoading ? 0.4 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: double.infinity,
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: widget.outlined
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    border: Border.all(color: AppTheme.accent, width: 1.5),
                    color: Colors.transparent,
                  )
                : BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                    gradient: gradient,
                    color: gradient == null ? AppTheme.surfaceLight : null,
                    boxShadow: gradient != null
                        ? [
                            BoxShadow(
                              color: gradient.colors.first.withOpacity(0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ]
                        : null,
                  ),
            child: Center(
              child: widget.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(widget.icon,
                              color: widget.outlined ? AppTheme.accent : Colors.white, size: 18),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(
                            widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: widget.outlined ? AppTheme.accent : Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

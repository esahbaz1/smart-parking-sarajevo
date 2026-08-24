import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/parking_model.dart';
import '../services/prediction_service.dart';
import 'glass_card.dart';

class ParkingCard extends StatefulWidget {
  final ParkingModel parking;
  final VoidCallback onTap;

  const ParkingCard({
    super.key,
    required this.parking,
    required this.onTap,
  });

  @override
  State<ParkingCard> createState() => _ParkingCardState();
}

class _ParkingCardState extends State<ParkingCard> {
  double _scale = 1.0;

  void _setPressed(bool pressed) => setState(() => _scale = pressed ? 0.98 : 1.0);

  @override
  Widget build(BuildContext context) {
    final parking = widget.parking;
    final statusColor = AppTheme.statusColor(parking.occupancyRate);
    final timeToFull = PredictionService.timeUntilFull(parking);

    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          child: GlassCard(
            radius: AppTheme.radiusMd,
            blur: 14,
            padding: const EdgeInsets.fromLTRB(6, 14, 16, 14),
            child: Row(
              children: [
                
                Container(
                  width: 4,
                  height: 54,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [statusColor, statusColor.withOpacity(0.3)],
                    ),
                  ),
                ),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor.withOpacity(0.12),
                    border: Border.all(color: statusColor.withOpacity(0.45), width: 1.5),
                    boxShadow: AppTheme.glowShadow(statusColor, blur: 14, opacity: 0.18),
                  ),
                  child: Center(
                    child: Text(
                      '${parking.availableSpots}',
                      style: TextStyle(
                        color: statusColor,
                        fontSize: parking.availableSpots > 99 ? 12 : 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parking.naziv,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        parking.adresa,
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 9),
                      Row(
                        children: [
                          _Tag('${(parking.occupancyRate * 100).toInt()}% puno', statusColor),
                          const SizedBox(width: 6),
                          _Tag('⏱ $timeToFull', AppTheme.textMuted),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                      child: Text(
                        '${parking.pricePerHour.toStringAsFixed(1)} KM',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Text('/sat', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                    const SizedBox(height: 10),
                    const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textMuted, size: 14),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color color;
  const _Tag(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
    );
  }
}

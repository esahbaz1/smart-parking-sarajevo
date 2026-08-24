import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models/parking_model.dart';
import '../services/prediction_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/glass_card.dart';
import '../providers/parking_provider.dart';
import '../services/api_service.dart';
import 'route_screen.dart';

class ParkingDetailsScreen extends StatefulWidget {
  final ParkingModel parking; 

  const ParkingDetailsScreen({super.key, required this.parking});

  @override
  State<ParkingDetailsScreen> createState() => _ParkingDetailsScreenState();
}

class _ParkingDetailsScreenState extends State<ParkingDetailsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  bool _isFavorite = false;
  bool _favoriteBusy = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _loadFavoriteState();
  }

  Future<void> _loadFavoriteState() async {
    final ids = await ApiService.getFavoriteIds();
    if (mounted && ids.contains(widget.parking.id)) {
      setState(() => _isFavorite = true);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite() async {
    if (_favoriteBusy) return;
    setState(() => _favoriteBusy = true);
    final result = await ApiService.toggleFavorite(widget.parking.id);
    if (mounted) {
      setState(() {
        _isFavorite = result;
        _favoriteBusy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ParkingProvider>(
      builder: (context, provider, _) {
        final ParkingModel p = widget.parking;
        

        final occupancy = p.occupancyRate;
        final statusColor = AppTheme.statusColor(occupancy);
        final blockingProb = p.erlangBProbability;

        return Scaffold(
          backgroundColor: AppTheme.background,
          body: Stack(
            children: [
              
              Container(
                height: 260,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      statusColor.withOpacity(0.15),
                      AppTheme.background,
                    ],
                  ),
                ),
              ),
              
              SafeArea(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      children: [
                        
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                                    color: AppTheme.textPrimary),
                                onPressed: () => Navigator.pop(context),
                              ),
                              Expanded(
                                child: Text(
                                  p.naziv,
                                  style: Theme.of(context).textTheme.headlineMedium,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: statusColor.withOpacity(0.3)),
                                ),
                                child: Text(
                                  AppTheme.statusLabel(occupancy),
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _toggleFavorite,
                                child: Container(
                                  width: 36, height: 36,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppTheme.surfaceGlass,
                                    border: Border.all(color: AppTheme.border),
                                  ),
                                  child: Icon(
                                    _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                    color: _isFavorite ? AppTheme.accentRed : AppTheme.textMuted,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                
                                Row(
                                  children: [
                                    Icon(Icons.location_on_outlined,
                                        color: AppTheme.textMuted, size: 16),
                                    const SizedBox(width: 6),
                                    Text(p.adresa,
                                        style: Theme.of(context).textTheme.bodyMedium),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                
                                Row(
                                  children: [
                                    Expanded(
                                      child: _StatCard(
                                        label: 'Slobodna mjesta',
                                        value: '${p.availableSpots}',
                                        sub: 'od ${p.totalSpots}',
                                        color: statusColor,
                                        icon: Icons.local_parking_rounded,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _StatCard(
                                        label: 'Cijena',
                                        value: '${p.pricePerHour.toStringAsFixed(1)}',
                                        sub: 'KM / sat',
                                        color: AppTheme.accent,
                                        icon: Icons.payments_outlined,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _StatCard(
                                        label: 'Popunjenost',
                                        value: '${(occupancy * 100).toStringAsFixed(0)}%',
                                        sub: 'trenutno',
                                        color: statusColor,
                                        icon: Icons.pie_chart_outline_rounded,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _StatCard(
                                        label: 'Predikcija pune',
                                        value: PredictionService.timeUntilFull(p),
                                        sub: 'do popune',
                                        color: AppTheme.accentAmber,
                                        icon: Icons.timer_outlined,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                
                                _buildOccupancyBar(p, statusColor),
                                const SizedBox(height: 24),
                                
                                _buildPredictionCard(p),
                                const SizedBox(height: 24),
                                
                                _buildErlangCard(p, blockingProb),
                                const SizedBox(height: 24),
                                
                                _buildHourlyChart(p),
                                const SizedBox(height: 32),
                                
                                Row(
                                  children: [
                                    Expanded(
                                      child: CustomButton(
                                        label: '🧭 Navigiraj',
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => RouteScreen(parking: p),
                                            ),
                                          );
                                        },
                                        outlined: true,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: CustomButton(
                                        label: '📅 Rezerviši',
                                        onPressed: () => Navigator.pushNamed(
                                          context,
                                          '/reservation',
                                          arguments: p,
                                        ),
                                        gradient: AppTheme.primaryGradient,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _SecondaryActionButton(
                                        icon: Icons.chat_bubble_outline_rounded,
                                        label: 'Chat',
                                        onTap: () => Navigator.pushNamed(
                                          context,
                                          '/parking-chat',
                                          arguments: p,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _SecondaryActionButton(
                                        icon: Icons.report_gmailerrorred_rounded,
                                        label: 'Prijavi problem',
                                        onTap: () => Navigator.pushNamed(
                                          context,
                                          '/report-issue',
                                          arguments: p,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  
  Widget _buildPredictionCard(ParkingModel p) {
    final in15 = PredictionService.predictAvailableSpots(p, 15);
    final in30 = PredictionService.predictAvailableSpots(p, 30);
    final in60 = PredictionService.predictAvailableSpots(p, 60);

    return GlassCard(
      padding: const EdgeInsets.all(20),
      blur: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(
                shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 8),
              const Text('AI predikcija slobodnih mjesta',
                  style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Procjena na osnovu trenutnog stanja i historijskih šablona zauzetosti.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _predictionSlot('za 15 min', in15, p.totalSpots)),
              const SizedBox(width: 10),
              Expanded(child: _predictionSlot('za 30 min', in30, p.totalSpots)),
              const SizedBox(width: 10),
              Expanded(child: _predictionSlot('za 60 min', in60, p.totalSpots)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _predictionSlot(String label, int predicted, int total) {
    final ratio = total > 0 ? predicted / total : 0.0;
    final color = AppTheme.statusColor(1 - ratio);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text('$predicted', style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildOccupancyBar(ParkingModel p, Color color) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      blur: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Popunjenost parkinga',
                  style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
              Text(
                '${p.totalSpots - p.availableSpots} / ${p.totalSpots}',
                style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              Container(
                height: 10,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceLight,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutCubic,
                height: 10,
                width: (MediaQuery.of(context).size.width - 80) * p.occupancyRate,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  gradient: LinearGradient(
                    colors: [color.withOpacity(0.6), color],
                  ),
                  boxShadow: [
                    BoxShadow(color: color.withOpacity(0.4), blurRadius: 6),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErlangCard(ParkingModel p, double blockingProb) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      blur: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.analytics_outlined, color: AppTheme.accent, size: 18),
              SizedBox(width: 8),
              Text(
                'Teorija čekanja (Erlang B)',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Vjerovatnoća blokiranja',
                  value: '${(blockingProb * 100).toStringAsFixed(1)}%',
                  color: AppTheme.accentRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStat(
                  label: 'Intenzitet saobraćaja',
                  value: '${(p.lambda / p.mu).toStringAsFixed(2)} Erl',
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Predikcija za 30 min',
                  value: '${PredictionService.predictAvailableSpots(p, 30)} mjesta',
                  color: AppTheme.accentGreen,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStat(
                  label: 'Predikcija za 60 min',
                  value: '${PredictionService.predictAvailableSpots(p, 60)} mjesta',
                  color: AppTheme.accentAmber,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHourlyChart(ParkingModel p) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      blur: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Popunjenost tokom dana',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: CustomPaint(
              painter: _BarChartPainter(p.hourlyOccupancy),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 8),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('00h', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
              Text('06h', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
              Text('12h', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
              Text('18h', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
              Text('23h', style: TextStyle(color: AppTheme.textMuted, fontSize: 10)),
            ],
          ),
        ],
      ),
    );
  }
}


class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String sub;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceGlass,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(sub,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<double> data;
  _BarChartPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    final barWidth = size.width / data.length;
    final maxH = size.height;
    final currentHour = DateTime.now().hour;

    for (int i = 0; i < data.length; i++) {
      final val = data[i];
      final barH = val * maxH;
      final x = i * barWidth;
      final isNow = i == currentHour;

      Color barColor;
      if (val < 0.6) barColor = AppTheme.statusFree;
      else if (val < 0.85) barColor = AppTheme.statusMedium;
      else barColor = AppTheme.statusFull;

      final paint = Paint()
        ..color = isNow ? barColor : barColor.withOpacity(0.45)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 2, maxH - barH, barWidth - 4, barH),
          const Radius.circular(3),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _SecondaryActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SecondaryActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surfaceGlass,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.accent, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

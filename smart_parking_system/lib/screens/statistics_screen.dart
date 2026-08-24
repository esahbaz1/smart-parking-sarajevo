import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/user_provider.dart';
import '../providers/parking_provider.dart';
import '../widgets/glass_card.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen>
    with TickerProviderStateMixin {
  late AnimationController _numberController;
  late AnimationController _chartController;
  final List<AnimationController> _cardControllers = [];

  final List<_StatData> _weeklyData = const [
    _StatData('Pon', 0.75),
    _StatData('Uto', 0.60),
    _StatData('Sri', 0.85),
    _StatData('Čet', 0.45),
    _StatData('Pet', 0.90),
    _StatData('Sub', 0.55),
    _StatData('Ned', 0.30),
  ];

  @override
  void initState() {
    super.initState();
    _numberController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _chartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    for (int i = 0; i < 4; i++) {
      final c = AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 400 + i * 100),
      );
      _cardControllers.add(c);
    }

    Future.delayed(const Duration(milliseconds: 200), () {
      _numberController.forward();
      _chartController.forward();
      for (int i = 0; i < _cardControllers.length; i++) {
        Future.delayed(Duration(milliseconds: i * 120), () {
          _cardControllers[i].forward();
        });
      }
    });
  }

  @override
  void dispose() {
    _numberController.dispose();
    _chartController.dispose();
    for (final c in _cardControllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;
    final provider = context.watch<ParkingProvider>();
    final avgOccupancy = provider.allParkings.isEmpty
        ? 0.0
        : provider.allParkings
                .map((p) => p.occupancyRate)
                .reduce((a, b) => a + b) /
            provider.allParkings.length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: AppTheme.textPrimary),
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Statistika',
                            style: Theme.of(context).textTheme.displayMedium),
                        Text('Tvoja aktivnost & grad',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  _buildTimeBadge(),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    
                    if (user != null) ...[
                      _buildSectionHeader('👤 Tvoja aktivnost'),
                      const SizedBox(height: 12),
                      _buildPersonalStats(user),
                      const SizedBox(height: 24),
                    ],
                    
                    _buildSectionHeader('🏙 Grad Sarajevo danas'),
                    const SizedBox(height: 12),
                    _buildCityStats(provider, avgOccupancy),
                    const SizedBox(height: 24),
                    
                    _buildSectionHeader('📊 Tjedno opterećenje'),
                    const SizedBox(height: 12),
                    _buildWeeklyChart(),
                    const SizedBox(height: 24),
                    
                    _buildSectionHeader('🌿 Ekološki uticaj'),
                    const SizedBox(height: 12),
                    _buildEnvironmentCard(user),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeBadge() {
    final now = DateTime.now();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: AppTheme.glassDecoration(radius: 12),
      child: Text(
        '${now.day}.${now.month}.${now.year}',
        style: const TextStyle(
            color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildSectionHeader(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildPersonalStats(user) {
    final stats = [
      _PersonalStat(
        'Ukupno parkinga',
        '${user.totalParkings}',
        'puta',
        Icons.local_parking_rounded,
        AppTheme.accent,
        0,
      ),
      _PersonalStat(
        'Ušteda vremena',
        '${user.totalMinutesSaved.toInt()}',
        'minuta',
        Icons.timer_rounded,
        AppTheme.accentGreen,
        1,
      ),
      _PersonalStat(
        'CO₂ ušteda',
        '${user.totalCO2Saved.toStringAsFixed(1)}',
        'kg CO₂',
        Icons.eco_rounded,
        Color(0xFF00E676),
        2,
      ),
      _PersonalStat(
        'Novca uštedio',
        '${(user.totalParkings * 1.5).toStringAsFixed(0)}',
        'KM',
        Icons.savings_rounded,
        AppTheme.accentAmber,
        3,
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: stats.map((s) {
        final ctrl = _cardControllers[s.index];
        return AnimatedBuilder(
          animation: ctrl,
          builder: (context, child) {
            return Opacity(
              opacity: ctrl.value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - ctrl.value)),
                child: child,
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: s.color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: s.color.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(s.icon, color: s.color, size: 22),
                const Spacer(),
                AnimatedBuilder(
                  animation: _numberController,
                  builder: (_, __) {
                    final val = double.tryParse(s.value) ?? 0;
                    final animVal = val * _numberController.value;
                    return RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: animVal.toStringAsFixed(
                                s.value.contains('.') ? 1 : 0),
                            style: TextStyle(
                              color: s.color,
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                          TextSpan(
                            text: ' ${s.unit}',
                            style: const TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Text(s.label,
                    style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCityStats(ParkingProvider provider, double avgOccupancy) {
    final statusColor = AppTheme.statusColor(avgOccupancy);
    final totalAvailable = provider.allParkings
        .fold(0, (sum, p) => sum + p.availableSpots);
    final totalSpots =
        provider.allParkings.fold(0, (sum, p) => sum + p.totalSpots);

    return GlassCard(
      padding: const EdgeInsets.all(20),
      blur: 14,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Slobodna mjesta u gradu',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 13)),
                    const SizedBox(height: 4),
                    AnimatedBuilder(
                      animation: _numberController,
                      builder: (_, __) {
                        return Text(
                          '${(totalAvailable * _numberController.value).toInt()} / $totalSpots',
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor.withOpacity(0.1),
                  border: Border.all(color: statusColor.withOpacity(0.3), width: 2),
                ),
                child: Center(
                  child: Text(
                    '${(avgOccupancy * 100).toInt()}%',
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          ...provider.allParkings.map((p) {
            final c = AppTheme.statusColor(p.occupancyRate);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 100,
                    child: Text(p.naziv.split(' ').last,
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 11),
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: AnimatedBuilder(
                        animation: _chartController,
                        builder: (_, __) {
                          return LinearProgressIndicator(
                            value: p.occupancyRate * _chartController.value,
                            backgroundColor: AppTheme.surfaceLight,
                            valueColor: AlwaysStoppedAnimation<Color>(c),
                            minHeight: 6,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${p.availableSpots}',
                    style: TextStyle(
                        color: c, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildWeeklyChart() {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      blur: 14,
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _weeklyData.map((d) {
                final color = AppTheme.statusColor(d.value);
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        AnimatedBuilder(
                          animation: _chartController,
                          builder: (_, __) {
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 600),
                              height: 100 * d.value * _chartController.value,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [color, color.withOpacity(0.4)],
                                ),
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(6)),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(d.day,
                            style: const TextStyle(
                                color: AppTheme.textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentCard(user) {
    final co2 = user?.totalCO2Saved ?? 12.4;
    final trees = (co2 / 21).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0A1F0F), Color(0xFF0D2A1A)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00E676).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Text('🌿', style: TextStyle(fontSize: 48)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pozitivan ekološki uticaj',
                    style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                const SizedBox(height: 8),
                Text(
                  'Uštedilo si ${co2.toStringAsFixed(1)} kg CO₂ — '
                  'ekvivalent $trees stabala drveća',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatData {
  final String day;
  final double value;
  const _StatData(this.day, this.value);
}

class _PersonalStat {
  final String label;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final int index;
  const _PersonalStat(
      this.label, this.value, this.unit, this.icon, this.color, this.index);
}

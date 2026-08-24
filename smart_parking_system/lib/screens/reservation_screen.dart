import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../models/parking_model.dart';
import '../services/api_service.dart';
import '../providers/user_provider.dart';
import '../services/session_store.dart';
import '../widgets/custom_button.dart';
import '../widgets/glass_card.dart';
import 'premium_checkout_screen.dart';

class ReservationScreen extends StatefulWidget {
  final ParkingModel parking;
  const ReservationScreen({super.key, required this.parking});

  @override
  State<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends State<ReservationScreen>
    with SingleTickerProviderStateMixin {
  DateTime _selectedTime = DateTime.now().add(const Duration(minutes: 15));
  int _durationHours = 1;
  bool _isLoading = false;
  Map<String, dynamic>? _reservationResult;
  late AnimationController _successController;
  late Animation<double> _scaleAnim;

  double get _totalPrice => widget.parking.pricePerHour * _durationHours;

  @override
  void initState() {
    super.initState();
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _successController.dispose();
    super.dispose();
  }

  Future<void> _confirmReservation() async {
    final userProvider = context.read<UserProvider>();
    final user = userProvider.user;
    if (user == null) return;

    
    final vehicleId = userProvider.primaryVehicleId ?? '1';

    setState(() => _isLoading = true);
    try {
      final result = await ApiService.createReservation(
        parkingId: widget.parking.id,
        vehicleId: vehicleId,
        startTime: _selectedTime,
        duration: Duration(hours: _durationHours),
      );
      if (mounted) {
        setState(() {
          _reservationResult = result;
          _isLoading = false;
        });
        _successController.forward();
        
        
        CarLocationStore.save(
          lat: widget.parking.lat,
          lng: widget.parking.lng,
          label: widget.parking.naziv,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Greška: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: AppTheme.accentRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  
  String get _reservationId {
    if (_reservationResult == null) return '-';
    final id = _reservationResult!['reservation_id'] ??
                _reservationResult!['reservationId'] ??
                '-';
    return id.toString();
  }

  String get _qrCode {
    if (_reservationResult == null) return '';
    return (_reservationResult!['qr_code'] ??
            _reservationResult!['qrCode'] ??
            'SP-MOCK').toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Rezervacija'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _reservationResult != null ? _buildSuccessView() : _buildFormView(),
    );
  }

  Widget _buildFormView() {
    final isPremium = context.watch<UserProvider>().isPremium;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GlassCard(
            padding: const EdgeInsets.all(20),
            blur: 14,
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.local_parking_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.parking.naziv, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(widget.parking.adresa, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isPremium) ...[
            const SizedBox(height: 16),
            _buildPremiumBanner(),
          ],
          const SizedBox(height: 24),
          _buildSectionTitle('Početak rezervacije'),
          const SizedBox(height: 12),
          _buildTimePicker(),
          const SizedBox(height: 24),
          _buildSectionTitle('Trajanje'),
          const SizedBox(height: 12),
          _buildDurationSelector(),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF001A33), Color(0xFF002244)]),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.accent.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                _buildPriceRow('Cijena po satu', '${widget.parking.pricePerHour.toStringAsFixed(1)} KM'),
                const Divider(color: AppTheme.border, height: 24),
                _buildPriceRow('Trajanje', '$_durationHours sat${_durationHours > 1 ? "a" : ""}'),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('UKUPNO',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1)),
                    ShaderMask(
                      shaderCallback: (bounds) => AppTheme.primaryGradient.createShader(bounds),
                      child: Text('${_totalPrice.toStringAsFixed(2)} KM',
                          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          CustomButton(
            label: 'Potvrdi rezervaciju',
            isLoading: _isLoading,
            onPressed: isPremium ? _confirmReservation : null,
            gradient: AppTheme.primaryGradient,
            icon: Icons.check_rounded,
          ),
          if (!isPremium) ...[
            const SizedBox(height: 12),
            Center(
              child: Text('Rezervacije su dostupne samo za Premium korisnike',
                  style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
            ),
          ],
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildPremiumBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.auroraGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentBlue.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 32),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Postani Premium', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
                Text('Otključaj rezervacije i više pogodnosti',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              final bought = await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => const PremiumCheckoutScreen()),
              );
              
              
              if (bought == true && mounted) setState(() {});
            },
            child: const Text('Kupi', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildTimePicker() {
    return GestureDetector(
      onTap: () async {
        final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_selectedTime));
        if (time != null && mounted) {
          setState(() {
            _selectedTime = DateTime(_selectedTime.year, _selectedTime.month, _selectedTime.day, time.hour, time.minute);
          });
        }
      },
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        blur: 14,
        child: Row(
          children: [
            const Icon(Icons.access_time_rounded, color: AppTheme.accent, size: 24),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Odabrano vrijeme', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationSelector() {
    return Row(
      children: List.generate(5, (i) {
        final hours = i + 1;
        final isSelected = _durationHours == hours;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _durationHours = hours),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: i < 4 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                gradient: isSelected ? AppTheme.primaryGradient : null,
                color: isSelected ? null : AppTheme.surfaceGlass,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isSelected ? Colors.transparent : AppTheme.border),
              ),
              child: Column(
                children: [
                  Text('$hours',
                      style: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.textSecondary,
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  Text('sat${hours > 1 ? "a" : ""}',
                      style: TextStyle(
                          color: isSelected ? Colors.white.withOpacity(0.8) : AppTheme.textMuted,
                          fontSize: 10)),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSuccessView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ScaleTransition(
          scale: _scaleAnim,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentGreen.withOpacity(0.15),
                  border: Border.all(color: AppTheme.accentGreen.withOpacity(0.5), width: 2),
                ),
                child: const Icon(Icons.check_rounded, color: AppTheme.accentGreen, size: 50),
              ),
              const SizedBox(height: 24),
              const Text('Rezervacija potvrđena!',
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Rezervacija #$_reservationId', style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(_qrCode, style: const TextStyle(color: AppTheme.accent, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 32),
              Container(
                width: 200, height: 200,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.all(16),
                child: CustomPaint(painter: _QRMockPainter()),
              ),
              const SizedBox(height: 12),
              const Text('Prikaži QR kod na ulazu parkinga',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              const SizedBox(height: 40),
              CustomButton(
                label: 'Nazad na mapu',
                onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false),
                gradient: AppTheme.primaryGradient,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(text,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3));
  }

  Widget _buildPriceRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _QRMockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.black..style = PaintingStyle.fill;
    final cell = size.width / 10;
    const pattern = [
      [1,1,1,1,1,1,1,0,0,0],[1,0,0,0,0,0,1,0,1,0],[1,0,1,1,1,0,1,0,0,1],
      [1,0,1,1,1,0,1,0,1,1],[1,0,1,1,1,0,1,0,0,0],[1,0,0,0,0,0,1,0,1,0],
      [1,1,1,1,1,1,1,0,0,1],[0,0,0,0,0,0,0,0,1,0],[1,0,1,0,1,0,0,1,0,1],
      [0,1,0,1,0,1,1,0,1,1],
    ];
    for (int row = 0; row < pattern.length; row++) {
      for (int col = 0; col < pattern[row].length; col++) {
        if (pattern[row][col] == 1) {
          canvas.drawRect(Rect.fromLTWH(col * cell, row * cell, cell, cell), p);
        }
      }
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../core/theme.dart';
import '../services/location_service.dart';
import '../services/session_store.dart';
import '../widgets/custom_button.dart';
import '../widgets/glass_card.dart';
import 'ar_navigation_screen.dart';

class FindMyCarScreen extends StatefulWidget {
  const FindMyCarScreen({super.key});

  @override
  State<FindMyCarScreen> createState() => _FindMyCarScreenState();
}

class _FindMyCarScreenState extends State<FindMyCarScreen> {
  Map<String, dynamic>? _carLocation;
  double? _distanceMeters;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await CarLocationStore.load();
    if (!mounted) return;
    setState(() {
      _carLocation = saved;
      _isLoading = false;
    });

    if (saved != null) {
      try {
        final hasPermission = await LocationService.ensurePermission();
        if (hasPermission) {
          final pos = await LocationService.getCurrentPosition();
          final distance = Geolocator.distanceBetween(
            pos.latitude, pos.longitude,
            saved['lat'] as double, saved['lng'] as double,
          );
          if (mounted) setState(() => _distanceMeters = distance);
        }
      } catch (_) {}
    }
  }

  Future<void> _saveCurrentLocationAsCar() async {
    setState(() => _isLoading = true);
    try {
      final hasPermission = await LocationService.ensurePermission();
      if (!hasPermission) {
        _showMessage('Potrebna je dozvola za lokaciju.', isError: true);
        setState(() => _isLoading = false);
        return;
      }
      final pos = await LocationService.getCurrentPosition();
      await CarLocationStore.save(
        lat: pos.latitude,
        lng: pos.longitude,
        label: 'Parkirano ${_formatNow()}',
      );
      await _load();
      if (mounted) _showMessage('Lokacija vozila je sačuvana!');
    } catch (e) {
      _showMessage('Greška: $e', isError: true);
      setState(() => _isLoading = false);
    }
  }

  String _formatNow() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  void _showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppTheme.accentRed : AppTheme.accentGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  String get _distanceLabel {
    if (_distanceMeters == null) return '';
    if (_distanceMeters! < 1000) return '${_distanceMeters!.round()} m od tebe';
    return '${(_distanceMeters! / 1000).toStringAsFixed(1)} km od tebe';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Nađi moj auto'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_carLocation != null) ...[
                    GlassCard(
                      padding: const EdgeInsets.all(20),
                      blur: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 50, height: 50,
                                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.primaryGradient),
                                child: const Icon(Icons.directions_car_filled_rounded, color: Colors.white),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(_carLocation!['label'] as String,
                                        style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
                                    const SizedBox(height: 3),
                                    Text(
                                      _distanceMeters != null ? _distanceLabel : 'Računam udaljenost...',
                                      style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    CustomButton(
                      label: 'Pokreni AR navigaciju do auta',
                      icon: Icons.explore_rounded,
                      gradient: AppTheme.primaryGradient,
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ArNavigationScreen(
                            targetLat: _carLocation!['lat'] as double,
                            targetLng: _carLocation!['lng'] as double,
                            targetLabel: _carLocation!['label'] as String,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ] else ...[
                    Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.directions_car_outlined, color: AppTheme.textMuted, size: 56),
                            const SizedBox(height: 16),
                            const Text(
                              'Još nisi sačuvao lokaciju vozila.',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  CustomButton(
                    label: _carLocation == null ? 'Ovdje sam parkirao auto' : 'Ažuriraj lokaciju auta',
                    icon: Icons.add_location_alt_outlined,
                    outlined: _carLocation != null,
                    gradient: _carLocation == null ? AppTheme.primaryGradient : null,
                    onPressed: _saveCurrentLocationAsCar,
                  ),
                ],
              ),
            ),
    );
  }
}

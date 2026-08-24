import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../core/theme.dart';
import '../models/parking_model.dart';
import '../services/location_service.dart';
import '../services/route_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/centered_popup.dart';


class RouteScreen extends StatefulWidget {
  final ParkingModel parking;
  const RouteScreen({super.key, required this.parking});

  @override
  State<RouteScreen> createState() => _RouteScreenState();
}

class _RouteScreenState extends State<RouteScreen> {
  static const double _arrivalThresholdMeters = 25;

  final MapController _mapController = MapController();
  RouteResult? _route;
  ll.LatLng? _myPosition;
  String? _error;
  bool _loading = true;
  bool _arrived = false;
  int _stepIndex = 0;

  StreamSubscription<Position>? _positionSub;
  bool _initialFitDone = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final hasPermission = await LocationService.ensurePermission();
      if (!hasPermission) {
        setState(() {
          _error = 'Dozvola za lokaciju je odbijena. Omogući lokaciju da bismo mogli izračunati rutu.';
          _loading = false;
        });
        return;
      }
      final pos = await LocationService.getCurrentPosition();
      final myLatLng = ll.LatLng(pos.latitude, pos.longitude);
      final dest = ll.LatLng(widget.parking.lat, widget.parking.lng);

      final route = await RouteService.getDrivingRoute(from: myLatLng, to: dest);

      setState(() {
        _myPosition = myLatLng;
        _route = route;
        _loading = false;
        
        
        _stepIndex = route.steps.length > 1 ? 1 : 0;
      });

      _fitBounds();
      _startLiveTracking();
    } catch (e) {
      setState(() {
        _error = 'Greška pri učitavanju rute: $e';
        _loading = false;
      });
    }
  }

  void _fitBounds() {
    final route = _route;
    if (route == null || route.points.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final bounds = LatLngBounds.fromPoints(route.points);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(48)),
      );
      _initialFitDone = true;
    });
  }

  void _startLiveTracking() {
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 3),
    ).listen(
      _onPositionUpdate,
      onError: (e) => debugPrint('[RouteScreen] Greška GPS stream-a: $e'),
      cancelOnError: false,
    );
  }

  void _onPositionUpdate(Position pos) {
    final route = _route;
    if (route == null || !mounted) return;

    final myLatLng = ll.LatLng(pos.latitude, pos.longitude);
    setState(() => _myPosition = myLatLng);

    if (_arrived || route.steps.isEmpty) return;

    
    final currentStep = route.steps[_stepIndex];
    final distanceToStep = Geolocator.distanceBetween(
      pos.latitude, pos.longitude,
      currentStep.location.latitude, currentStep.location.longitude,
    );

    if (distanceToStep < _arrivalThresholdMeters) {
      if (_stepIndex >= route.steps.length - 1) {
        setState(() => _arrived = true);
      } else {
        setState(() => _stepIndex += 1);
      }
    }

    
    if (_initialFitDone) {
      try {
        _mapController.move(myLatLng, _mapController.camera.zoom);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final dest = ll.LatLng(widget.parking.lat, widget.parking.lng);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: Text('Navigacija do ${widget.parking.naziv}'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: dest,
                        initialZoom: 14,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'ba.smartparking.app',
                        ),
                        if (_route != null)
                          PolylineLayer(polylines: [
                            Polyline(
                              points: _route!.points,
                              strokeWidth: 5,
                              color: AppTheme.accent,
                            ),
                          ]),
                        MarkerLayer(markers: [
                          if (_myPosition != null)
                            Marker(
                              point: _myPosition!,
                              width: 26, height: 26,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 3),
                                ),
                              ),
                            ),
                          Marker(
                            point: dest,
                            width: 40, height: 40,
                            alignment: Alignment.topCenter,
                            child: const Icon(Icons.location_on, color: Colors.redAccent, size: 40),
                          ),
                        ]),
                      ],
                    ),
                    if (_route != null) ...[
                      Positioned(
                        left: 16, right: 16, top: 16,
                        child: _buildInstructionBanner(),
                      ),
                      Positioned(
                        left: 16, right: 16, bottom: 24,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildRouteInfoCard(),
                            const SizedBox(height: 10),
                            _buildStepsListButton(),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Pokušaj ponovo')),
          ],
        ),
      ),
    );
  }

  
  Widget _buildInstructionBanner() {
    final route = _route!;
    if (_arrived) {
      return GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        blur: 14,
        child: Row(
          children: [
            const Icon(Icons.flag_rounded, color: AppTheme.accentGreen, size: 32),
            const SizedBox(width: 14),
            const Expanded(
              child: Text(
                'Stigli ste do cilja',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      );
    }

    if (route.steps.isEmpty) return const SizedBox.shrink();
    final step = route.steps[_stepIndex];
    final distance = _myPosition != null
        ? Geolocator.distanceBetween(
            _myPosition!.latitude, _myPosition!.longitude,
            step.location.latitude, step.location.longitude,
          )
        : step.distanceMeters;

    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      blur: 14,
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.primaryGradient),
            child: Icon(step.icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatRouteDistance(distance),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 2),
                Text(
                  step.instruction,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInfoCard() {
    final r = _route!;
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      blur: 14,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _infoItem(Icons.route, '${r.distanceKm} km', 'udaljenost'),
          Container(width: 1, height: 32, color: AppTheme.border),
          _infoItem(Icons.access_time, '${r.durationMin.round()} min', 'vožnjom'),
        ],
      ),
    );
  }

  Widget _buildStepsListButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: _showStepsSheet,
        style: TextButton.styleFrom(
          backgroundColor: AppTheme.surfaceGlass,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        ),
        icon: const Icon(Icons.list_alt_rounded, color: Colors.white70, size: 18),
        label: const Text('Prikaži sve upute', style: TextStyle(color: Colors.white70)),
      ),
    );
  }

  void _showStepsSheet() {
    final steps = _route!.steps;
    showCenteredPopup(
      context: context,
      builder: (_) => GlassCard(
        radius: AppTheme.radiusLg,
        blur: 26,
        tint: AppTheme.surface.withOpacity(0.94),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text('Sve upute',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.5),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: steps.length,
                  separatorBuilder: (_, __) => Divider(color: AppTheme.border, height: 1),
                  itemBuilder: (_, i) {
                    final s = steps[i];
                    final active = i == _stepIndex && !_arrived;
                    return ListTile(
                      leading: Icon(s.icon, color: active ? AppTheme.accent : Colors.white54),
                      title: Text(
                        s.instruction,
                        style: TextStyle(
                          color: active ? Colors.white : Colors.white70,
                          fontWeight: active ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: s.distanceMeters > 0
                          ? Text(formatRouteDistance(s.distanceMeters), style: const TextStyle(color: Colors.white54, fontSize: 12))
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.accent, size: 20),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}

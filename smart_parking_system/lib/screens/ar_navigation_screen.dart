import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import '../core/theme.dart';
import '../services/location_service.dart';


class ArNavigationScreen extends StatefulWidget {
  final double targetLat;
  final double targetLng;
  final String targetLabel;

  const ArNavigationScreen({
    super.key,
    required this.targetLat,
    required this.targetLng,
    required this.targetLabel,
  });

  @override
  State<ArNavigationScreen> createState() => _ArNavigationScreenState();
}

class _ArNavigationScreenState extends State<ArNavigationScreen> {
  CameraController? _cameraController;
  bool _cameraReady = false;
  bool _cameraFailed = false;

  StreamSubscription<CompassEvent>? _compassSub;
  StreamSubscription<Position>? _positionSub;

  double _heading = 0;       
  double? _distanceMeters;
  double? _bearingToTarget;  

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initCompass();
    _initPosition();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _cameraFailed = true);
        return;
      }
      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(backCamera, ResolutionPreset.medium, enableAudio: false);
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _cameraController = controller;
        _cameraReady = true;
      });
    } catch (_) {
      if (mounted) setState(() => _cameraFailed = true);
    }
  }

  void _initCompass() {
    if (FlutterCompass.events == null) return;
    _compassSub = FlutterCompass.events!.listen((event) {
      if (event.heading != null && mounted) {
        setState(() => _heading = event.heading!);
      }
    });
  }

  Future<void> _initPosition() async {
    final hasPermission = await LocationService.ensurePermission();
    if (!hasPermission) return;

    void update(Position pos) {
      if (!mounted) return;
      final distance = Geolocator.distanceBetween(
        pos.latitude, pos.longitude, widget.targetLat, widget.targetLng,
      );
      final bearing = Geolocator.bearingBetween(
        pos.latitude, pos.longitude, widget.targetLat, widget.targetLng,
      );
      setState(() {
        _distanceMeters = distance;
        _bearingToTarget = bearing < 0 ? bearing + 360 : bearing;
      });
    }

    try {
      final initial = await LocationService.getCurrentPosition();
      update(initial);
    } catch (_) {}

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 2),
    ).listen(update);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _compassSub?.cancel();
    _positionSub?.cancel();
    super.dispose();
  }

  
  double get _arrowRotationRadians {
    if (_bearingToTarget == null) return 0;
    final diff = (_bearingToTarget! - _heading + 360) % 360;
    return diff * (3.14159265 / 180);
  }

  String get _distanceLabel {
    if (_distanceMeters == null) return '...';
    if (_distanceMeters! < 1000) return '${_distanceMeters!.round()} m';
    return '${(_distanceMeters! / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          
          if (_cameraReady && _cameraController != null)
            CameraPreview(_cameraController!)
          else if (_cameraFailed)
            _RadarFallback(heading: _heading, bearing: _bearingToTarget)
          else
            const Center(child: CircularProgressIndicator(color: AppTheme.accent)),

          
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.55),
                  Colors.transparent,
                  Colors.black.withOpacity(0.7),
                ],
                stops: const [0, 0.3, 1],
              ),
            ),
          ),

          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40, height: 40,
                      decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.targetLabel,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),

          
          Center(
            child: Transform.rotate(
              angle: _arrowRotationRadians,
              child: Container(
                width: 90, height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.primaryGradient,
                  boxShadow: AppTheme.glowShadow(AppTheme.accent, blur: 30, opacity: 0.5),
                ),
                child: const Icon(Icons.navigation_rounded, color: Colors.white, size: 46),
              ),
            ),
          ),

          
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                    border: Border.all(color: Colors.white.withOpacity(0.15)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _distanceLabel,
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _cameraFailed
                            ? 'Prati strelicu — kamera nije dostupna, koristi se radar prikaz'
                            : 'Prati strelicu do cilja',
                        style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _RadarFallback extends StatelessWidget {
  final double heading;
  final double? bearing;
  const _RadarFallback({required this.heading, required this.bearing});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0E1A),
      child: Center(
        child: Icon(Icons.explore_outlined, color: Colors.white.withOpacity(0.06), size: 260),
      ),
    );
  }
}

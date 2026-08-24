import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import '../services/location_service.dart';
import '../services/prediction_service.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../providers/parking_provider.dart';
import '../providers/user_provider.dart';
import '../providers/notification_provider.dart';
import '../widgets/parking_card.dart';
import '../widgets/heatmap_legend.dart';
import '../widgets/glass_card.dart';
import '../widgets/centered_popup.dart';
import '../models/parking_model.dart';
import 'find_my_car_screen.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  late DraggableScrollableController _sheetController;
  late AnimationController _fabController;
  late IO.Socket socket;
  final TextEditingController _searchController = TextEditingController();
  int _currentTab = 0;
  geo.Position? _userPosition; 

  @override
  void initState() {
    super.initState();
    _sheetController = DraggableScrollableController();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ParkingProvider>().loadParkings();
      _initSocket();
      _silentlyFetchLocation();
      final userId = context.read<UserProvider>().user?.id;
      if (userId != null) context.read<NotificationProvider>().connect(userId);
    });
  }

  
  Future<void> _silentlyFetchLocation() async {
    try {
      final hasPermission = await LocationService.ensurePermission();
      if (!hasPermission) return;
      final pos = await LocationService.getCurrentPosition();
      if (mounted) setState(() => _userPosition = pos);
    } catch (_) {
      
    }
  }

  void _initSocket() {
    
    
    socket = IO.io(
      AppConstants.wsUrl,
      <String, dynamic>{
        'transports':   ['websocket'],
        'autoConnect':  true,
        'reconnection': true,              
        'reconnectionDelay': 4000,
        'reconnectionAttempts': 5,
        'timeout': 5000,
      },
    );

    socket.onConnect((_) {
      debugPrint('[WS] Povezan na simulator');
    });

    socket.onDisconnect((_) {
      debugPrint('[WS] Odspojen od simulatora');
    });

    socket.onConnectError((err) {
      debugPrint('[WS] Greška konekcije: $err');
    });

    
    socket.on('parking_update', (data) {
      if (data == null || !mounted) return;

      
      final parkingId   = data['parking_id'].toString();
      final newAvailable = data['available_spots'] as int;

      context.read<ParkingProvider>().updateAvailability(parkingId, newAvailable);
    });
  }

  @override
  void dispose() {
    _sheetController.dispose();
    _fabController.dispose();
    _searchController.dispose();
    socket.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          _buildMapPlaceholder(),
          
          Positioned(
            top: 0, left: 0, right: 0,
            height: 250,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.background.withOpacity(0.92),
                    AppTheme.background.withOpacity(0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(child: _buildTopBar()),
          Positioned(
            top: MediaQuery.of(context).padding.top + 168,
            right: 16,
            child: const HeatmapLegend(),
          ),
          _buildBottomSheet(),
          _buildQuickActionsCluster(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  final MapController _mapController = MapController();

  Widget _buildMapPlaceholder() {
    return Consumer<ParkingProvider>(
      builder: (context, provider, _) {
        return FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: ll.LatLng(AppConstants.sarajevoLat, AppConstants.sarajevoLng),
            initialZoom: AppConstants.defaultZoom,
            minZoom: 10,
            maxZoom: 19,
          ),
          children: [
            TileLayer(
              
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'ba.smartparking.app',
            ),
            MarkerLayer(
              markers: provider.allParkings.map((p) => _buildMarker(p)).toList(),
            ),
          ],
        );
      },
    );
  }

  Marker _buildMarker(ParkingModel parking) {
    final color = AppTheme.statusColor(parking.occupancyRate);
    return Marker(
      point: ll.LatLng(parking.lat, parking.lng),
      width: 56,
      height: 66,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () => Navigator.pushNamed(context, '/parking-details', arguments: parking),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _PulsingMarker(color: color, parking: parking),
            Container(width: 2, height: 10, color: color.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Consumer<UserProvider>(
            builder: (context, userProvider, _) {
              final ime = userProvider.user?.ime;
              final greeting = _greetingForNow();
              return Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => const LinearGradient(
                              colors: [AppTheme.textPrimary, AppTheme.accentSky],
                            ).createShader(bounds),
                            child: Text(
                              ime != null && ime.isNotEmpty ? '$greeting, $ime 👋' : '$greeting! 👋',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Pronađi slobodan parking u blizini',
                            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 10),
                          _buildLiveStatsRow(),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          Row(
            children: [
              Expanded(
                child: Consumer<ParkingProvider>(
                  builder: (context, provider, _) {
                    return GlassCard(
                      radius: AppTheme.radiusPill,
                      blur: 20,
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
                        onChanged: provider.setSearchQuery,
                        decoration: const InputDecoration(
                          hintText: 'Pretraži parking...',
                          prefixIcon: Icon(Icons.search_rounded, color: AppTheme.textMuted),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              _buildNotificationBell(),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => Navigator.pushNamed(context, '/profile'),
                child: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.primaryGradient,
                    boxShadow: [BoxShadow(color: AppTheme.accent.withOpacity(0.3), blurRadius: 12)],
                  ),
                  child: Consumer<UserProvider>(
                    builder: (context, userProvider, _) {
                      return Center(
                        child: Text(
                          userProvider.user?.ime.substring(0, 1) ?? 'A',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLiveStatsRow() {
    return Consumer<ParkingProvider>(
      builder: (context, provider, _) {
        final parkings = provider.allParkings;
        final totalFree = parkings.fold<int>(0, (sum, p) => sum + p.availableSpots);
        final nearOpenCount = parkings.where((p) => p.isAvailable).length;
        return Row(
          children: [
            _statChip(
              icon: Icons.local_parking_rounded,
              value: '$totalFree',
              label: 'slobodno',
              color: AppTheme.accentGreen,
            ),
            const SizedBox(width: 8),
            _statChip(
              icon: Icons.map_rounded,
              value: '${parkings.length}',
              label: 'lokacija',
              color: AppTheme.accent,
            ),
            const SizedBox(width: 8),
            _statChip(
              icon: Icons.check_circle_rounded,
              value: '$nearOpenCount',
              label: 'otvoreno',
              color: AppTheme.accentSky,
            ),
          ],
        );
      },
    );
  }

  Widget _statChip({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 13),
          const SizedBox(width: 5),
          Text(value,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800)),
          const SizedBox(width: 3),
          Text(label,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildNotificationBell() {
    return Consumer<NotificationProvider>(
      builder: (context, notif, _) {
        final unread = notif.unreadCount;
        return GestureDetector(
          onTap: () => _openNotificationsSheet(context),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              GlassCard(
                radius: 24,
                blur: 20,
                padding: const EdgeInsets.all(12),
                child: const Icon(Icons.notifications_rounded, color: AppTheme.textPrimary, size: 22),
              ),
              if (unread > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    constraints: const BoxConstraints(minWidth: 18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppTheme.accentRed, Color(0xFFFF7A8A)]),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.background, width: 1.5),
                    ),
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  void _openNotificationsSheet(BuildContext context) {
    final notif = context.read<NotificationProvider>();
    showGeneralDialog(
      context: context,
      barrierLabel: 'Notifikacije',
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.55),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (dialogContext, __, ___) {
        final screenSize = MediaQuery.of(dialogContext).size;
        final maxWidth = screenSize.width < 480 ? screenSize.width * 0.92 : 420.0;
        final maxHeight = screenSize.height * 0.72;
        return Center(
          child: Material(
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight),
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 40, offset: Offset(0, 12))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Notifikacije', style: Theme.of(dialogContext).textTheme.headlineMedium),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () => notif.markAllRead(),
                                child: const Text('Označi sve', style: TextStyle(color: AppTheme.accent, fontSize: 13)),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted, size: 20),
                                onPressed: () => Navigator.of(dialogContext).pop(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: AppTheme.border, height: 1),
                    Flexible(
                      child: Consumer<NotificationProvider>(
                        builder: (context, notif, _) {
                          if (notif.items.isEmpty) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.notifications_off_outlined, color: AppTheme.textMuted, size: 40),
                                    SizedBox(height: 12),
                                    Text('Nema notifikacija još', style: TextStyle(color: AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                            );
                          }
                          return ListView.builder(
                            shrinkWrap: true,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                            itemCount: notif.items.length,
                            itemBuilder: (context, index) {
                              final n = notif.items[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: n.read ? AppTheme.surfaceGlass : AppTheme.surfaceLight,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppTheme.border),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(_iconForType(n.type), color: AppTheme.accent, size: 20),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(n.title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14)),
                                          const SizedBox(height: 4),
                                          Text(n.body, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, animation, __, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween(begin: 0.94, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    ).whenComplete(() => notif.markAllRead());
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'reservation':
        return Icons.event_available_rounded;
      case 'chat':
        return Icons.chat_bubble_rounded;
      case 'freeSpot':
        return Icons.local_parking_rounded;
      default:
        return Icons.local_offer_rounded;
    }
  }

  String _greetingForNow() {
    final hour = DateTime.now().hour;
    if (hour < 5) return 'Dobro veče';
    if (hour < 12) return 'Dobro jutro';
    if (hour < 18) return 'Dobar dan';
    return 'Dobro veče';
  }

  Widget _buildBottomSheet() {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.35,
      minChildSize: 0.16,
      maxChildSize: 0.85,
      builder: (context, scrollController) {
        
        
        void handleDragUpdate(DragUpdateDetails details) {
          final screenHeight = MediaQuery.of(context).size.height;
          final delta = details.primaryDelta ?? 0;
          final newSize = _sheetController.size - (delta / screenHeight);
          _sheetController.jumpTo(newSize.clamp(0.16, 0.85));
        }

        void handleDragEnd(DragEndDetails details) {
          
          
          const stops = [0.16, 0.35, 0.6, 0.85];
          final current = _sheetController.size;
          double closest = stops.first;
          double minDiff = (current - stops.first).abs();
          for (final s in stops.skip(1)) {
            final diff = (current - s).abs();
            if (diff < minDiff) {
              minDiff = diff;
              closest = s;
            }
          }
          _sheetController.animateTo(
            closest,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
            border: Border.all(color: AppTheme.border, width: 1),
            boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 30)],
          ),
          child: Column(
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.resizeUpDown,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: handleDragUpdate,
                  onVerticalDragEnd: handleDragEnd,
                  onTap: () {
                    
                    
                    final target = _sheetController.size < 0.3 ? 0.6 : 0.16;
                    _sheetController.animateTo(
                      target,
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutCubic,
                    );
                  },
                  child: Container(
                    color: Colors.transparent,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    child: Column(
                      children: [
                        Container(
                          width: 40, height: 4,
                          decoration: BoxDecoration(color: AppTheme.textMuted, borderRadius: BorderRadius.circular(2)),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Consumer<ParkingProvider>(
                              builder: (context, provider, _) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Parkings u blizini',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.headlineMedium),
                                    Text('${provider.parkings.length} lokacija pronađeno',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context).textTheme.bodyMedium),
                                  ],
                                );
                              },
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pushNamed(context, '/statistics'),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(20)),
                                child: const Row(
                                  children: [
                                    Icon(Icons.bar_chart_rounded, size: 16, color: Colors.white),
                                    SizedBox(width: 6),
                                    Text('Statistika', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Consumer<ParkingProvider>(
                  builder: (context, provider, _) {
                    if (provider.isLoading) {
                      return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
                    }
                    final recommended = _bestRecommendation(provider.parkings);
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                      itemCount: provider.parkings.length + (recommended != null ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (recommended != null && index == 0) {
                          return _SmartAssistantBanner(
                            parking: recommended,
                            onTap: () => Navigator.pushNamed(context, '/parking-details', arguments: recommended),
                          );
                        }
                        final parking = provider.parkings[recommended != null ? index - 1 : index];
                        return ParkingCard(
                          parking: parking,
                          onTap: () => Navigator.pushNamed(context, '/parking-details', arguments: parking),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  
  ParkingModel? _bestRecommendation(List<ParkingModel> parkings) {
    if (_userPosition == null || parkings.isEmpty) return null;
    ParkingModel? best;
    double bestScore = -1;
    for (final p in parkings) {
      final distanceKm = geo.Geolocator.distanceBetween(
            _userPosition!.latitude, _userPosition!.longitude, p.lat, p.lng,
          ) /
          1000;
      final score = PredictionService.recommendationScore(p, distanceKm);
      if (score > bestScore) {
        bestScore = score;
        best = p;
      }
    }
    return best;
  }

  Future<void> _goToMyLocation() async {
    try {
      final hasPermission = await LocationService.ensurePermission();
      if (!hasPermission) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dozvola za lokaciju nije odobrena')),
          );
        }
        return;
      }
      final pos = await LocationService.getCurrentPosition();
      _mapController.move(ll.LatLng(pos.latitude, pos.longitude), 16);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lokacija nedostupna: $e')),
        );
      }
    }
  }

  
  Widget _buildQuickActionsCluster() {
    return Positioned(
      right: 16,
      bottom: 340,
      child: Column(
        children: [
          _QuickActionButton(
            icon: Icons.directions_car_filled_rounded,
            tooltip: 'Nađi moj auto',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FindMyCarScreen()),
            ),
          ),
          const SizedBox(height: 10),
          _QuickActionButton(
            icon: Icons.report_gmailerrorred_rounded,
            tooltip: 'Prijavi problem',
            onTap: () => _pickParkingThen((p) =>
                Navigator.pushNamed(context, '/report-issue', arguments: p)),
          ),
          const SizedBox(height: 10),
          _QuickActionButton(
            icon: Icons.chat_bubble_outline_rounded,
            tooltip: 'Chat sa parkingom',
            onTap: () => _pickParkingThen((p) =>
                Navigator.pushNamed(context, '/parking-chat', arguments: p)),
          ),
          const SizedBox(height: 10),
          _QuickActionButton(
            icon: Icons.my_location_rounded,
            tooltip: 'Moja lokacija',
            onTap: _goToMyLocation,
            highlighted: true,
          ),
        ],
      ),
    );
  }

  
  void _pickParkingThen(void Function(ParkingModel) onPicked) {
    final parkings = context.read<ParkingProvider>().nearbyParkings;
    if (parkings.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Parkinzi se još učitavaju, pokušaj ponovo za trenutak.')),
      );
      return;
    }
    showCenteredPopup(
      context: context,
      builder: (sheetContext) => GlassCard(
        radius: AppTheme.radiusLg,
        blur: 26,
        tint: AppTheme.surface.withOpacity(0.92),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Odaberi parking', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.45),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: parkings.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final p = parkings[index];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.local_parking_rounded, color: AppTheme.accent),
                      title: Text(p.naziv, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                      subtitle: Text(p.adresa, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
                      onTap: () {
                        Navigator.pop(sheetContext);
                        onPicked(p);
                      },
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

  Widget _buildBottomNav() {
    final items = [
      {'icon': Icons.map_outlined,      'activeIcon': Icons.map_rounded,       'label': 'Mapa'},
      {'icon': Icons.bar_chart_outlined, 'activeIcon': Icons.bar_chart_rounded, 'label': 'Statistika'},
      {'icon': Icons.person_outline,     'activeIcon': Icons.person_rounded,    'label': 'Profil'},
    ];

    return Container(
      color: Colors.transparent,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      child: SafeArea(
        top: false,
        child: GlassCard(
          radius: AppTheme.radiusPill,
          blur: 24,
          tint: AppTheme.surface.withOpacity(0.97),
          shadow: const [BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 6))],
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item     = items[index];
              final isActive = _currentTab == index;
              return GestureDetector(
                onTap: () {
                  setState(() => _currentTab = index);
                  if (index == 1) Navigator.pushNamed(context, '/statistics');
                  if (index == 2) Navigator.pushNamed(context, '/profile');
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isActive ? AppTheme.primaryGradient : null,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                    boxShadow: isActive ? AppTheme.glowShadow(AppTheme.accent, blur: 16, opacity: 0.35) : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isActive ? item['activeIcon'] as IconData : item['icon'] as IconData,
                        color: isActive ? Colors.white : AppTheme.textMuted,
                        size: 20,
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 8),
                        Text(
                          item['label'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}


class _PulsingMarker extends StatefulWidget {
  final Color color;
  final ParkingModel parking;
  const _PulsingMarker({required this.color, required this.parking});

  @override
  State<_PulsingMarker> createState() => _PulsingMarkerState();
}

class _PulsingMarkerState extends State<_PulsingMarker> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    _pulse = Tween<double>(begin: 1.0, end: 1.4).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56, height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, __) => Transform.scale(
              scale: _pulse.value,
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withOpacity(0.15 * (2 - _pulse.value)),
                ),
              ),
            ),
          ),
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: widget.color, width: 2.5),
              boxShadow: [BoxShadow(color: widget.color.withOpacity(0.4), blurRadius: 10)],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${widget.parking.availableSpots}',
                  style: TextStyle(color: widget.color, fontSize: 13, fontWeight: FontWeight.w700, height: 1),
                ),
                const Text('mjesta', style: TextStyle(color: AppTheme.textMuted, fontSize: 7)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


class _MapMockPainter extends CustomPainter {
  final List<ParkingModel> parkings;
  _MapMockPainter(this.parkings);

  @override
  void paint(Canvas canvas, Size size) {
    final roadPaint = Paint()
      ..color = const Color(0xFF1C2537)
      ..strokeWidth = 12
      ..strokeCap = StrokeCap.round;

    final roads = [
      [Offset(0, size.height * 0.4),          Offset(size.width, size.height * 0.42)],
      [Offset(size.width * 0.5, 0),            Offset(size.width * 0.52, size.height)],
      [Offset(0, size.height * 0.6),           Offset(size.width * 0.7, size.height * 0.58)],
      [Offset(size.width * 0.25, 0),           Offset(size.width * 0.3, size.height * 0.7)],
      [Offset(size.width * 0.7, size.height * 0.3), Offset(size.width, size.height * 0.5)],
    ];
    for (final road in roads) {
      canvas.drawLine(road[0], road[1], roadPaint);
    }

    final blockPaint = Paint()..color = const Color(0xFF111827);
    final blocks = [
      Rect.fromLTWH(size.width * 0.1,  size.height * 0.1,  size.width * 0.3,  size.height * 0.15),
      Rect.fromLTWH(size.width * 0.55, size.height * 0.12, size.width * 0.3,  size.height * 0.12),
      Rect.fromLTWH(size.width * 0.1,  size.height * 0.5,  size.width * 0.2,  size.height * 0.1),
      Rect.fromLTWH(size.width * 0.6,  size.height * 0.55, size.width * 0.25, size.height * 0.15),
    ];
    for (final block in blocks) {
      canvas.drawRRect(RRect.fromRectAndRadius(block, const Radius.circular(4)), blockPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00D4FF).withOpacity(0.02)
      ..strokeWidth = 0.5;
    const spacing = 30.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool highlighted;

  const _QuickActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: highlighted ? AppTheme.primaryGradient : null,
            color: highlighted ? null : AppTheme.surface,
            border: highlighted ? null : Border.all(color: AppTheme.border, width: 1),
            boxShadow: highlighted
                ? AppTheme.glowShadow(AppTheme.accent, blur: 16, opacity: 0.35)
                : const [BoxShadow(color: Colors.black38, blurRadius: 12)],
          ),
          child: Icon(icon, color: highlighted ? Colors.white : AppTheme.accent, size: 22),
        ),
      ),
    );
  }
}

class _SmartAssistantBanner extends StatelessWidget {
  final ParkingModel parking;
  final VoidCallback onTap;
  const _SmartAssistantBanner({required this.parking, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppTheme.auroraGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          boxShadow: AppTheme.glowShadow(AppTheme.accentBlue, blur: 20, opacity: 0.3),
        ),
        child: Row(
          children: [
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Smart Parking Assistant preporučuje',
                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(parking.naziv,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                  Text('${parking.availableSpots} mjesta · ${parking.pricePerHour.toStringAsFixed(1)} KM/h',
                      style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 14),
          ],
        ),
      ),
    );
  }
}

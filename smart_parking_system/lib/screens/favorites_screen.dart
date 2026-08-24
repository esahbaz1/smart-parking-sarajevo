import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/parking_model.dart';
import '../services/api_service.dart';
import '../widgets/parking_card.dart';


class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late Future<List<ParkingModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = ApiService.getFavoriteParkings();
  }

  Future<void> _reload() async {
    setState(() => _future = ApiService.getFavoriteParkings());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Omiljeni parkinzi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        color: AppTheme.accent,
        backgroundColor: AppTheme.surface,
        child: FutureBuilder<List<ParkingModel>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppTheme.accent));
            }
            if (snapshot.hasError) {
              return _buildMessage(
                icon: Icons.error_outline_rounded,
                text: 'Greška pri učitavanju: ${snapshot.error}',
              );
            }
            final favorites = snapshot.data ?? [];
            if (favorites.isEmpty) {
              return _buildMessage(
                icon: Icons.favorite_border_rounded,
                text: 'Još nemaš omiljenih parkinga.\nDodaj ih dodirom na ❤ na ekranu detalja parkinga.',
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: favorites.length,
              itemBuilder: (context, index) {
                final parking = favorites[index];
                return ParkingCard(
                  parking: parking,
                  onTap: () async {
                    await Navigator.pushNamed(context, '/parking-details', arguments: parking);
                    
                    if (mounted) _reload();
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildMessage({required IconData icon, required String text}) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: AppTheme.textMuted, size: 48),
                  const SizedBox(height: 14),
                  Text(text, textAlign: TextAlign.center,
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

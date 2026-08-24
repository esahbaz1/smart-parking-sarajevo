import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../core/theme.dart';
import '../models/parking_model.dart';
import '../services/api_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/glass_card.dart';
import '../widgets/centered_popup.dart';

class ReportIssueScreen extends StatefulWidget {
  final ParkingModel parking;
  const ReportIssueScreen({super.key, required this.parking});

  @override
  State<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends State<ReportIssueScreen> {
  final _opisController = TextEditingController();
  final _picker = ImagePicker();

  XFile? _photo;
  Uint8List? _photoPreview;
  bool _isSubmitting = false;

  static const _categories = [
    'Oštećenje kolovoza / rupa',
    'Neispravan senzor / rampa',
    'Oštećena signalizacija / oznaka',
    'Vandalizam',
    'Ostalo',
  ];
  String _kategorija = _categories.first;

  
  List<String> _spotNumbers = [];
  String? _selectedSpot;
  bool _loadingSpots = true;

  @override
  void initState() {
    super.initState();
    _loadSpots();
  }

  Future<void> _loadSpots() async {
    final spots = await ApiService.getParkingSpots(widget.parking.id);
    if (!mounted) return;
    setState(() {
      _spotNumbers = spots
          .map((s) => (s as Map<String, dynamic>)['spot_number']?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      _loadingSpots = false;
    });
  }

  @override
  void dispose() {
    _opisController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 80, maxWidth: 1600);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      setState(() {
        _photo = file;
        _photoPreview = bytes;
      });
    } catch (e) {
      _showMessage('Nije moguće otvoriti kameru/galeriju: $e', isError: true);
    }
  }

  void _showPhotoSourceSheet() {
    showCenteredPopup(
      context: context,
      builder: (_) => GlassCard(
        radius: AppTheme.radiusLg,
        blur: 22,
        tint: AppTheme.surface.withOpacity(0.94),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.accent),
                title: const Text('Slikaj kamerom', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined, color: AppTheme.accent),
                title: const Text('Odaberi iz galerije', style: TextStyle(color: AppTheme.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppTheme.accentRed : AppTheme.accentGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      final opis = '[$_kategorija] ${_opisController.text.trim()}';
      await ApiService.submitParkingReport(
        parkingId: widget.parking.id,
        opis: opis,
        photo: _photo,
        spotNumber: _selectedSpot,
      );
      if (!mounted) return;
      _showMessage('Prijava je poslana. Hvala što pomažeš da parking bude bolji!');
      Navigator.pop(context);
    } catch (e) {
      _showMessage('Greška pri slanju prijave: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Prijavi problem'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GlassCard(
              padding: const EdgeInsets.all(14),
              blur: 14,
              child: Row(
                children: [
                  const Icon(Icons.local_parking_rounded, color: AppTheme.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(widget.parking.naziv,
                        style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Vrsta problema', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((c) {
                final selected = c == _kategorija;
                return GestureDetector(
                  onTap: () => setState(() => _kategorija = c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: selected ? AppTheme.primaryGradient : null,
                      color: selected ? null : AppTheme.surfaceGlass,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? Colors.transparent : AppTheme.border),
                    ),
                    child: Text(c,
                        style: TextStyle(
                          color: selected ? Colors.white : AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        )),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            const Text('Mjesto na parkingu (opciono)',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            const Text('Ako znaš tačno mjesto, upravnik parkinga će ga vidjeti na mapi.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
            const SizedBox(height: 10),
            _loadingSpots
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: SizedBox(
                      height: 18, width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
                    ),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _selectedSpot = null),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: _selectedSpot == null ? AppTheme.primaryGradient : null,
                            color: _selectedSpot == null ? null : AppTheme.surfaceGlass,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _selectedSpot == null ? Colors.transparent : AppTheme.border),
                          ),
                          child: Text('Ne znam',
                              style: TextStyle(
                                color: _selectedSpot == null ? Colors.white : AppTheme.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              )),
                        ),
                      ),
                      ..._spotNumbers.map((s) {
                        final selected = s == _selectedSpot;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedSpot = s),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              gradient: selected ? AppTheme.primaryGradient : null,
                              color: selected ? null : AppTheme.surfaceGlass,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: selected ? Colors.transparent : AppTheme.border),
                            ),
                            child: Text(s,
                                style: TextStyle(
                                  color: selected ? Colors.white : AppTheme.textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                )),
                          ),
                        );
                      }),
                    ],
                  ),
            const SizedBox(height: 24),
            const Text('Opis (opciono)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            GlassCard(
              blur: 14,
              child: TextField(
                controller: _opisController,
                maxLines: 4,
                style: const TextStyle(color: AppTheme.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Opiši šta se dogodilo (npr. lokacija, detalji oštećenja)...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('Fotografija', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _showPhotoSourceSheet,
              child: Container(
                height: 180,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceGlass,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: _photoPreview == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined, color: AppTheme.textMuted, size: 32),
                          SizedBox(height: 8),
                          Text('Dodaj sliku oštećenja', style: TextStyle(color: AppTheme.textMuted)),
                        ],
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(_photoPreview!, fit: BoxFit.cover),
                          Positioned(
                            right: 8, top: 8,
                            child: GestureDetector(
                              onTap: () => setState(() {
                                _photo = null;
                                _photoPreview = null;
                              }),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                child: const Icon(Icons.close, color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 32),
            CustomButton(
              label: 'Pošalji prijavu',
              isLoading: _isSubmitting,
              onPressed: _submit,
              gradient: AppTheme.primaryGradient,
              icon: Icons.send_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

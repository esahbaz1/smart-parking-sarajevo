import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../services/api_service.dart';
import '../widgets/custom_button.dart';
import '../widgets/glass_card.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _isSaving = false;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);

    if (_currentController.text.isEmpty) {
      setState(() => _error = 'Unesi trenutnu lozinku');
      return;
    }
    if (_newController.text.length < 6) {
      setState(() => _error = 'Nova lozinka mora imati najmanje 6 karaktera');
      return;
    }
    if (_newController.text != _confirmController.text) {
      setState(() => _error = 'Nova lozinka i potvrda se ne poklapaju');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await ApiService.changePassword(
        trenutnaLozinka: _currentController.text,
        novaLozinka: _newController.text,
      );
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lozinka je uspješno promijenjena.')),
      );
      _currentController.clear();
      _newController.clear();
      _confirmController.clear();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = 'Greška: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Sigurnost i privatnost'),
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
            const Text('Promijeni lozinku',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('Preporučujemo lozinku od najmanje 6 karaktera.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 20),

            _passwordField(
              controller: _currentController,
              hint: 'Trenutna lozinka',
              obscure: _obscureCurrent,
              onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
            ),
            const SizedBox(height: 14),
            _passwordField(
              controller: _newController,
              hint: 'Nova lozinka',
              obscure: _obscureNew,
              onToggle: () => setState(() => _obscureNew = !_obscureNew),
            ),
            const SizedBox(height: 14),
            _passwordField(
              controller: _confirmController,
              hint: 'Potvrdi novu lozinku',
              obscure: _obscureNew,
              onToggle: null,
            ),

            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: const TextStyle(color: AppTheme.accentRed, fontSize: 13)),
            ],

            const SizedBox(height: 22),
            CustomButton(
              label: 'Sačuvaj lozinku',
              isLoading: _isSaving,
              onPressed: _submit,
              gradient: AppTheme.primaryGradient,
              icon: Icons.lock_reset_rounded,
            ),

            const SizedBox(height: 32),
            const Text('Privatnost', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            GlassCard(
              radius: 18,
              blur: 14,
              child: Column(
                children: const [
                  _InfoRow(
                    icon: Icons.location_on_outlined,
                    title: 'Lokacija',
                    subtitle: 'Koristi se samo da ti pokažemo najbliže parkinge i za navigaciju — ne dijeli se s trećim stranama.',
                  ),
                  Divider(color: AppTheme.border, height: 1),
                  _InfoRow(
                    icon: Icons.storage_outlined,
                    title: 'Podaci naloga',
                    subtitle: 'Ime, email i historija parkiranja se čuvaju dok ne obrišeš nalog.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _passwordField({
    required TextEditingController controller,
    required String hint,
    required bool obscure,
    required VoidCallback? onToggle,
  }) {
    return GlassCard(
      blur: 12,
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          suffixIcon: onToggle == null
              ? null
              : IconButton(
                  icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      color: AppTheme.textMuted, size: 20),
                  onPressed: onToggle,
                ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _InfoRow({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.textMuted, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

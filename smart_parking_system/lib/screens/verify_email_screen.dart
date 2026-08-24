import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/user_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/mesh_background.dart';
import '../widgets/glass_card.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  bool _isResending = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_codeController.text.trim().length < 4) {
      _showMessage('Unesi kod koji si dobio/la na email', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    final success = await context.read<UserProvider>().verifyEmail(_codeController.text.trim());
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } else {
      _showMessage('Pogrešan ili istekao kod. Pokušaj ponovo.', isError: true);
    }
  }

  Future<void> _resend() async {
    setState(() => _isResending = true);
    final ok = await context.read<UserProvider>().resendVerificationCode();
    if (!mounted) return;
    setState(() => _isResending = false);
    _showMessage(ok ? 'Novi kod je poslan na email' : 'Greška pri slanju koda', isError: !ok);
  }

  void _showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppTheme.accentRed : AppTheme.accentGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final email = context.watch<UserProvider>().pendingVerificationEmail ?? '';

    return Scaffold(
      body: MeshBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppTheme.auroraGradient,
                    boxShadow: AppTheme.glowShadow(AppTheme.accentBlue, blur: 24, opacity: 0.4),
                  ),
                  child: const Icon(Icons.mark_email_read_outlined, color: Colors.white, size: 34),
                ),
                const SizedBox(height: 24),
                Text('Potvrdi email', style: Theme.of(context).textTheme.displayMedium),
                const SizedBox(height: 8),
                Text(
                  email.isEmpty
                      ? 'Poslali smo ti 6-cifreni kod na email.'
                      : 'Poslali smo 6-cifreni kod na:\n$email',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                GlassCard(
                  blur: 16,
                  child: TextField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 6,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 10,
                    ),
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                      hintText: '000000',
                      hintStyle: TextStyle(color: AppTheme.textMuted, letterSpacing: 10),
                      contentPadding: EdgeInsets.symmetric(vertical: 18),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                CustomButton(
                  label: 'Potvrdi',
                  isLoading: _isLoading,
                  onPressed: _verify,
                  gradient: AppTheme.primaryGradient,
                  icon: Icons.check_circle_outline,
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: _isResending ? null : _resend,
                    child: Text(
                      _isResending ? 'Šaljem...' : 'Nisi dobio/la kod? Pošalji ponovo',
                      style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

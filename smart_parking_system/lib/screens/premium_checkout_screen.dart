import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/user_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/glass_card.dart';
import '../widgets/mesh_background.dart';


class PremiumCheckoutScreen extends StatefulWidget {
  const PremiumCheckoutScreen({super.key});

  @override
  State<PremiumCheckoutScreen> createState() => _PremiumCheckoutScreenState();
}

class _PremiumCheckoutScreenState extends State<PremiumCheckoutScreen>
    with SingleTickerProviderStateMixin {
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isProcessing = false;
  String? _error;

  late final AnimationController _shineController;

  @override
  void initState() {
    super.initState();
    _shineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    _shineController.dispose();
    super.dispose();
  }

  
  String get _cardBrand {
    final digits = _cardNumberController.text.replaceAll(' ', '');
    if (digits.isEmpty) return '';
    if (digits.startsWith('4')) return 'VISA';
    if (digits.startsWith(RegExp(r'5[1-5]'))) return 'Mastercard';
    if (digits.startsWith(RegExp(r'3[47]'))) return 'AMEX';
    return 'CARD';
  }

  bool _luhnValid(String number) {
    final digits = number.replaceAll(' ', '');
    if (digits.length < 13 || digits.length > 19) return false;
    int sum = 0;
    bool alternate = false;
    for (int i = digits.length - 1; i >= 0; i--) {
      int n = int.tryParse(digits[i]) ?? -1;
      if (n < 0) return false;
      if (alternate) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
      alternate = !alternate;
    }
    return sum % 10 == 0;
  }

  bool _expiryValid(String value) {
    final match = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(value);
    if (match == null) return false;
    final month = int.parse(match.group(1)!);
    final year = int.parse('20${match.group(2)!}');
    if (month < 1 || month > 12) return false;
    final now = DateTime.now();
    final expiry = DateTime(year, month + 1, 0);
    return expiry.isAfter(now);
  }

  Future<void> _submit() async {
    setState(() => _error = null);

    if (_nameController.text.trim().length < 3) {
      setState(() => _error = 'Unesi ime kako stoji na kartici');
      return;
    }
    if (!_luhnValid(_cardNumberController.text)) {
      setState(() => _error = 'Broj kartice nije ispravan');
      return;
    }
    if (!_expiryValid(_expiryController.text.trim())) {
      setState(() => _error = 'Datum isteka nije ispravan (MM/GG)');
      return;
    }
    if (_cvvController.text.trim().length < 3) {
      setState(() => _error = 'CVV mora imati 3 cifre');
      return;
    }

    setState(() => _isProcessing = true);

    
    await Future.delayed(const Duration(milliseconds: 900));

    final ok = await context.read<UserProvider>().upgradeToPremium();

    if (!mounted) return;
    setState(() => _isProcessing = false);

    if (ok) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          child: GlassCard(
            blur: 22,
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.successGradient),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 16),
                const Text('Premium aktiviran!',
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text('Hvala ti — sad imaš pristup svim premium opcijama.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                const SizedBox(height: 20),
                CustomButton(
                  label: 'Super!',
                  gradient: AppTheme.primaryGradient,
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      setState(() => _error = 'Nešto je pošlo po zlu. Pokušaj ponovo.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Premium pretplata'),
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: MeshBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 50, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPlanHeader(),
                const SizedBox(height: 22),
                _buildAnimatedCardPreview(),
                const SizedBox(height: 28),

                _sectionLabel('Podaci za plaćanje'),
                const SizedBox(height: 12),

                const Text('Ime na kartici', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _field(_nameController, hint: 'Amina Hodžić', keyboardType: TextInputType.name, icon: Icons.person_outline_rounded),

                const SizedBox(height: 18),
                const Text('Broj kartice', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                _field(
                  _cardNumberController,
                  hint: '4242 4242 4242 4242',
                  keyboardType: TextInputType.number,
                  maxLength: 19,
                  formatter: _CardNumberFormatter(),
                  icon: Icons.credit_card_rounded,
                ),

                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Ističe (MM/GG)', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          _field(_expiryController, hint: '12/28', keyboardType: TextInputType.number, maxLength: 5, formatter: _ExpiryFormatter(), icon: Icons.event_rounded),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('CVV', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          _field(_cvvController, hint: '123', keyboardType: TextInputType.number, maxLength: 3, obscure: true, icon: Icons.lock_outline_rounded),
                        ],
                      ),
                    ),
                  ],
                ),

                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.accentRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.accentRed.withOpacity(0.35)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppTheme.accentRed, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_error!, style: const TextStyle(color: AppTheme.accentRed, fontSize: 13))),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 28),
                CustomButton(
                  label: 'Plati 4.99 KM',
                  isLoading: _isProcessing,
                  onPressed: _submit,
                  gradient: AppTheme.primaryGradient,
                  icon: Icons.lock_outline_rounded,
                ),
                const SizedBox(height: 18),
                _buildTrustRow(),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentAmber.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.accentAmber.withOpacity(0.25)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: AppTheme.accentAmber, size: 16),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Demo plaćanje — simulacija radi prikaza toka, ne šalje se '
                          'pravom platnom procesoru. Ne unosi stvarne podatke kartice.',
                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Text(text,
        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3));
  }

  Widget _buildPlanHeader() {
    return GlassCard(
      radius: AppTheme.radiusLg,
      blur: 20,
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46, height: 46,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.auroraGradient),
                child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Smart Parking Premium', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    const Text('Mjesečna pretplata · otkaži bilo kada',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              ShaderMask(
                shaderCallback: (b) => AppTheme.primaryGradient.createShader(b),
                child: const Text('4.99 KM',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 16),
          _perk(Icons.event_available_rounded, 'Neograničene rezervacije parking mjesta'),
          const SizedBox(height: 10),
          _perk(Icons.bolt_rounded, 'Prioritetni pristup Smart Assistant preporukama'),
          const SizedBox(height: 10),
          _perk(Icons.notifications_active_rounded, 'Real-time notifikacije o slobodnim mjestima'),
        ],
      ),
    );
  }

  Widget _perk(IconData icon, String text) {
    return Row(
      children: [
        Container(
          width: 26, height: 26,
          decoration: BoxDecoration(color: AppTheme.accentGreen.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: AppTheme.accentGreen, size: 14),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5))),
      ],
    );
  }

  Widget _buildAnimatedCardPreview() {
    return AnimatedBuilder(
      animation: _shineController,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.all(22),
          height: 190,
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: AppTheme.auroraGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            boxShadow: AppTheme.glowShadow(AppTheme.accentBlue, blur: 28, opacity: 0.35),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Stack(
              children: [
                
                
                Positioned.fill(
                  child: Transform.translate(
                    offset: Offset(
                      (-1.4 + 2.8 * _shineController.value) * 260,
                      0,
                    ),
                    child: Transform.rotate(
                      angle: -0.5,
                      child: Container(
                        width: 90,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0),
                              Colors.white.withOpacity(0.16),
                              Colors.white.withOpacity(0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 38, height: 28,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFFFFE9A8), Color(0xFFE8C466)]),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.wifi_rounded, color: Colors.white70, size: 20),
                            const SizedBox(width: 10),
                            Text(_cardBrand,
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                          ],
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      _cardNumberController.text.isEmpty
                          ? '•••• •••• •••• ••••'
                          : _formatCardPreview(_cardNumberController.text),
                      style: const TextStyle(color: Colors.white, fontSize: 20, letterSpacing: 2, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _nameController.text.isEmpty ? 'IME PREZIME' : _nameController.text.toUpperCase(),
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        Text(
                          _expiryController.text.isEmpty ? 'MM/GG' : _expiryController.text,
                          style: const TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrustRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.verified_user_rounded, color: AppTheme.textMuted, size: 14),
        const SizedBox(width: 6),
        const Text('Sigurno šifrovano', style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5)),
        const SizedBox(width: 16),
        const Icon(Icons.shield_outlined, color: AppTheme.textMuted, size: 14),
        const SizedBox(width: 6),
        const Text('PCI-DSS demo standard', style: TextStyle(color: AppTheme.textMuted, fontSize: 11.5)),
      ],
    );
  }

  String _formatCardPreview(String value) {
    final digits = value.replaceAll(' ', '').padRight(16, '•');
    final buffer = StringBuffer();
    for (int i = 0; i < 16; i++) {
      buffer.write(digits[i]);
      if ((i + 1) % 4 == 0 && i != 15) buffer.write(' ');
    }
    return buffer.toString();
  }

  Widget _field(
    TextEditingController controller, {
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int? maxLength,
    bool obscure = false,
    TextInputFormatter? formatter,
    IconData? icon,
  }) {
    return GlassCard(
      blur: 12,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLength: maxLength,
        obscureText: obscure,
        inputFormatters: formatter != null ? [formatter] : null,
        onChanged: (_) => setState(() {}),
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: icon != null ? Icon(icon, color: AppTheme.textMuted, size: 19) : null,
          border: InputBorder.none,
          counterText: '',
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}


class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      buffer.write(digits[i]);
      if ((i + 1) % 4 == 0 && i != digits.length - 1) buffer.write(' ');
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}


class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll('/', '');
    if (digits.length > 4) return oldValue;
    String formatted = digits;
    if (digits.length >= 3) {
      formatted = '${digits.substring(0, 2)}/${digits.substring(2)}';
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

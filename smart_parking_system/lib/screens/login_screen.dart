import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/user_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/mesh_background.dart';
import '../widgets/glass_card.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  final _imeController      = TextEditingController();
  final _prezimeController  = TextEditingController();
  final _telefonController  = TextEditingController();
  final _tabliceController  = TextEditingController();
  final _bojaController     = TextEditingController();
  final _formKey            = GlobalKey<FormState>();

  bool _obscurePassword = true;
  bool _isLoading       = false;
  bool _isGoogleLoading = false;
  bool _isRegisterMode  = false;

  
  String? _selectedMarka;
  String? _selectedModel;
  String  _vrstaVozila = 'automobil';

  late AnimationController _animController;
  late Animation<Offset>   _slideAnim;
  late Animation<double>   _fadeAnim;

  
  static const Map<String, List<String>> _markaModeli = {
    'Volkswagen': ['Golf 4','Golf 5','Golf 6','Golf 7','Golf 8','Passat','Polo','Tiguan','T-Roc','Caddy'],
    'BMW':        ['Serija 1','Serija 2','Serija 3','Serija 5','X1','X3','X5','X6','M3','M5'],
    'Mercedes':   ['A Klasa','C Klasa','E Klasa','GLA','GLC','GLE','Vito','Sprinter','CLA','AMG'],
    'Audi':       ['A1','A3','A4','A5','A6','Q3','Q5','Q7','TT','RS3'],
    'Toyota':     ['Yaris','Corolla','Camry','RAV4','Land Cruiser','Prius','Hilux','Auris','Avensis','C-HR'],
    'Ford':       ['Fiesta','Focus','Mondeo','Kuga','EcoSport','Ranger','Puma','Transit','Mustang','Edge'],
    'Opel':       ['Corsa','Astra','Insignia','Mokka','Zafira','Crossland','Grandland','Vivaro','Omega','Vectra'],
    'Škoda':      ['Fabia','Octavia','Superb','Karoq','Kodiaq','Scala','Kamiq','Rapid','Citigo','Enyaq'],
    'Renault':    ['Clio','Megane','Laguna','Kadjar','Captur','Duster','Twingo','Scenic','Zoe','Kangoo'],
    'Peugeot':    ['206','207','208','301','308','3008','5008','Partner','Boxer','RCZ'],
    'Hyundai':    ['i10','i20','i30','Tucson','Santa Fe','Elantra','Kona','Ioniq','ix35','i40'],
    'Kia':        ['Picanto','Rio','Ceed','Sportage','Sorento','Stinger','Niro','Soul','Stonic','EV6'],
    'Seat':       ['Ibiza','Leon','Arona','Ateca','Tarraco','Toledo','Mii','Alhambra','Exeo','Formentor'],
    'Fiat':       ['Punto','500','Bravo','Tipo','Panda','Doblo','Ducato','Linea','Stilo','Tempra'],
    'Nissan':     ['Micra','Juke','Qashqai','X-Trail','Navara','Leaf','Note','Pulsar','Murano','370Z'],
    'Honda':      ['Jazz','Civic','Accord','CR-V','HR-V','Fit','Legend','Pilot','Ridgeline','e'],
    'Mazda':      ['Mazda2','Mazda3','Mazda6','CX-3','CX-5','CX-9','MX-5','CX-30','BT-50','RX-8'],
    'Zastava':    ['Yugo 45','Yugo 55','Yugo 65','101','128','Skala 55','Skala 65','Florida','Rival','Poly'],
    'Ostalo':     ['Ostalo'],
  };

  static const List<String> _vrste = ['automobil','kombi','motocikl','kamion'];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _imeController.dispose();
    _prezimeController.dispose();
    _telefonController.dispose();
    _tabliceController.dispose();
    _bojaController.dispose();
    _animController.dispose();
    super.dispose();
  }

  
  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    bool success;

    if (_isRegisterMode) {
      success = await context.read<UserProvider>().register(
        ime: _imeController.text.trim(),
        prezime: _prezimeController.text.trim(),
        email: _emailController.text.trim(),
        lozinka: _passwordController.text,
        telefon: _telefonController.text.trim(),
        vozilo: {
          'tablice': _tabliceController.text.trim().toUpperCase(),
          'vrsta': _vrstaVozila,
          'marka': _selectedMarka ?? '',
          'model': _selectedModel ?? '',
          'boja': _bojaController.text.trim(),
        },
      );
    } else {
      success = await context.read<UserProvider>().login(
        _emailController.text.trim(),
        _passwordController.text,
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    final userProvider = context.read<UserProvider>();

    if (_isRegisterMode) {
      if (success) {
        
        Navigator.pushNamed(context, '/verify-email');
      } else {
        _showError('Registracija neuspješna. Možda email već postoji.');
      }
      return;
    }

    if (success) {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (userProvider.pendingVerificationEmail != null) {
      _showError('Email nije verifikovan. Unesi kod koji smo ti poslali.');
      Navigator.pushNamed(context, '/verify-email');
    } else {
      _showError('Pogrešan email ili lozinka.');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: AppTheme.accentRed,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  void _toggleMode() {
    setState(() {
      _isRegisterMode = !_isRegisterMode;
      _selectedMarka = null;
      _selectedModel = null;
    });
    _animController.reset();
    _animController.forward();
  }

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MeshBackground(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildHeader(),
                      const SizedBox(height: 32),
                      if (_isRegisterMode) ...[
                        _buildCard(
                          title: 'Lični podaci',
                          icon: Icons.person_outline_rounded,
                          children: [
                            _buildRow([
                              _buildInput(
                                controller: _imeController,
                                label: 'Ime',
                                hint: 'npr. Adnan',
                                icon: Icons.badge_outlined,
                                validator: (v) => v!.isEmpty ? 'Obavezno' : null,
                              ),
                              _buildInput(
                                controller: _prezimeController,
                                label: 'Prezime',
                                hint: 'npr. Kovačević',
                                icon: Icons.badge_outlined,
                                validator: (v) => v!.isEmpty ? 'Obavezno' : null,
                              ),
                            ]),
                            const SizedBox(height: 16),
                            _buildInput(
                              controller: _telefonController,
                              label: 'Broj telefona',
                              hint: 'npr. +387 61 123 456',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildCard(
                          title: 'Podaci o vozilu',
                          icon: Icons.directions_car_outlined,
                          subtitle: 'Opciono — možete dodati kasnije',
                          children: [
                            _buildInput(
                              controller: _tabliceController,
                              label: 'Registarske tablice',
                              hint: 'npr. E33-K-123',
                              icon: Icons.credit_card_outlined,
                              textCapitalization: TextCapitalization.characters,
                            ),
                            const SizedBox(height: 16),
                            _buildVrstaSelector(),
                            const SizedBox(height: 16),
                            _buildMarkaDropdown(),
                            const SizedBox(height: 16),
                            _buildModelDropdown(),
                            const SizedBox(height: 16),
                            _buildInput(
                              controller: _bojaController,
                              label: 'Boja vozila',
                              hint: 'npr. Crna, Bijela, Siva...',
                              icon: Icons.palette_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildCard(
                          title: 'Pristupni podaci',
                          icon: Icons.lock_outline_rounded,
                          children: [
                            _buildEmailField(),
                            const SizedBox(height: 16),
                            _buildPasswordField(),
                          ],
                        ),
                      ] else ...[
                        _buildCard(
                          title: 'Prijava',
                          icon: Icons.login_rounded,
                          children: [
                            _buildEmailField(),
                            const SizedBox(height: 16),
                            _buildPasswordField(),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {},
                                child: const Text('Zaboravili ste lozinku?',
                                    style: TextStyle(
                                        color: AppTheme.accent, fontSize: 13)),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 24),
                      CustomButton(
                        label: _isRegisterMode ? 'Kreiraj račun' : 'Prijavi se',
                        isLoading: _isLoading,
                        onPressed: _handleAuth,
                        gradient: AppTheme.primaryGradient,
                        icon: _isRegisterMode
                            ? Icons.person_add_outlined
                            : Icons.login_rounded,
                      ),
                      if (!_isRegisterMode) ...[
                        const SizedBox(height: 20),
                        _buildDivider(),
                        const SizedBox(height: 16),
                        _buildSocialButtons(),
                      ],
                      const SizedBox(height: 28),
                      _buildToggle(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  
  Widget _buildHeader() {
    return Column(
      children: [
        Center(
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accent.withOpacity(0.35),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Icon(Icons.local_parking_rounded,
                size: 34, color: Colors.white),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _isRegisterMode ? 'Kreiraj račun' : 'Dobrodošli nazad',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displayMedium,
        ),
        const SizedBox(height: 6),
        Text(
          _isRegisterMode
              ? 'Popunite podatke ispod za registraciju'
              : 'Prijavite se u Smart Parking Sarajevo',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    String? subtitle,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 16),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  if (subtitle != null)
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppTheme.textMuted, fontSize: 11)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: AppTheme.border, height: 1),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildRow(List<Widget> children) {
    return Row(
      children: children
          .expand((w) => [Expanded(child: w), const SizedBox(width: 12)])
          .toList()
        ..removeLast(),
    );
  }

  Widget _buildVrstaSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Vrsta vozila'),
        const SizedBox(height: 10),
        Row(
          children: _vrste.map((vrsta) {
            final isSelected = _vrstaVozila == vrsta;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _vrstaVozila = vrsta),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(
                      right: vrsta != _vrste.last ? 8 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    gradient: isSelected ? AppTheme.primaryGradient : null,
                    color: isSelected ? null : AppTheme.surfaceGlass,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : AppTheme.border,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        _vrstaIcon(vrsta),
                        color: isSelected ? Colors.white : AppTheme.textMuted,
                        size: 20,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        vrsta[0].toUpperCase() + vrsta.substring(1),
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppTheme.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMarkaDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Marka vozila'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.surfaceGlass,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedMarka,
              isExpanded: true,
              dropdownColor: AppTheme.surface,
              hint: const Text('Odaberite marku...',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 14)),
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
              icon: const Icon(Icons.expand_more_rounded,
                  color: AppTheme.textMuted),
              items: _markaModeli.keys.map((marka) {
                return DropdownMenuItem(
                  value: marka,
                  child: Text(marka),
                );
              }).toList(),
              onChanged: (v) => setState(() {
                _selectedMarka = v;
                _selectedModel = null;
              }),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModelDropdown() {
    final modeli = _selectedMarka != null
        ? _markaModeli[_selectedMarka]!
        : <String>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Model vozila'),
        const SizedBox(height: 8),
        AnimatedOpacity(
          opacity: _selectedMarka != null ? 1.0 : 0.4,
          duration: const Duration(milliseconds: 200),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.surfaceGlass,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _selectedMarka != null
                    ? AppTheme.border
                    : AppTheme.border.withOpacity(0.3),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedModel,
                isExpanded: true,
                dropdownColor: AppTheme.surface,
                hint: Text(
                  _selectedMarka == null
                      ? 'Prvo odaberite marku'
                      : 'Odaberite model...',
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 14),
                ),
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 15),
                icon: const Icon(Icons.expand_more_rounded,
                    color: AppTheme.textMuted),
                items: modeli.map((model) {
                  return DropdownMenuItem(
                    value: model,
                    child: Text(model),
                  );
                }).toList(),
                onChanged: _selectedMarka == null
                    ? null
                    : (v) => setState(() => _selectedModel = v),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return _buildInput(
      controller: _emailController,
      label: 'Email adresa',
      hint: 'npr. adnan@primjer.ba',
      icon: Icons.email_outlined,
      keyboardType: TextInputType.emailAddress,
      validator: (v) {
        if (v == null || v.isEmpty) return 'Unesite email adresu';
        if (!v.contains('@') || !v.contains('.')) return 'Nevažeći email';
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Lozinka'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: 'Minimum 6 karaktera',
            prefixIcon:
                const Icon(Icons.lock_outline, color: AppTheme.textMuted),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppTheme.textMuted,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Unesite lozinku';
            if (v.length < 6) return 'Lozinka mora imati minimum 6 karaktera';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization textCapitalization = TextCapitalization.words,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 20),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppTheme.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('ili nastavi sa',
              style: Theme.of(context).textTheme.bodyMedium),
        ),
        const Expanded(child: Divider(color: AppTheme.border)),
      ],
    );
  }

  Widget _buildSocialButtons() {
    return _SocialButton(
      icon: Icons.g_mobiledata_rounded,
      label: 'Nastavi sa Google računom',
      onPressed: _handleGoogleLogin,
      isLoading: _isGoogleLoading,
    );
  }

  Future<void> _handleGoogleLogin() async {
    setState(() => _isGoogleLoading = true);
    final userProvider = context.read<UserProvider>();
    final success = await userProvider.loginWithGoogle();
    if (!mounted) return;
    setState(() => _isGoogleLoading = false);

    if (success) {
      Navigator.pushReplacementNamed(context, '/home');
    } else if (userProvider.googleLoginError != null) {
      _showError(userProvider.googleLoginError!);
    }
    
  }

  Widget _buildToggle() {
    return Center(
      child: GestureDetector(
        onTap: _toggleMode,
        child: RichText(
          text: TextSpan(
            text: _isRegisterMode ? 'Već imaš račun? ' : 'Nemaš račun? ',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            children: [
              TextSpan(
                text: _isRegisterMode ? 'Prijavi se' : 'Registruj se',
                style: const TextStyle(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ));
  }

  IconData _vrstaIcon(String vrsta) {
    switch (vrsta) {
      case 'kombi':    return Icons.airport_shuttle_outlined;
      case 'motocikl': return Icons.two_wheeler_outlined;
      case 'kamion':   return Icons.local_shipping_outlined;
      default:         return Icons.directions_car_outlined;
    }
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 14),
        blur: 14,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading) ...[
              const SizedBox(
                width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
              ),
              const SizedBox(width: 10),
              const Text('Povezivanje...',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
            ] else ...[
              Icon(icon, color: AppTheme.textSecondary, size: 20),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500)),
            ],
          ],
        ),
      ),
    );
  }
}

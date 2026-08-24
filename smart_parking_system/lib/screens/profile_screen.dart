import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/user_provider.dart';
import '../providers/notification_provider.dart';
import '../widgets/custom_button.dart';
import '../widgets/glass_card.dart';
import 'premium_checkout_screen.dart';
import 'favorites_screen.dart';
import 'notifications_settings_screen.dart';
import 'security_screen.dart';
import 'help_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserProvider>().user;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            floating: false,
            pinned: true,
            backgroundColor: AppTheme.surface,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF001A2E), Color(0xFF0A0E1A)],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),
                      
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.primaryGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.accent.withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            user?.ime.substring(0, 1) ?? 'A',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user?.ime ?? 'Korisnik',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (user?.premium == true) ...[
                        const SizedBox(height: 4),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.workspace_premium_rounded,
                                color: Colors.amber, size: 14),
                            SizedBox(width: 4),
                            Text('Premium',
                                style: TextStyle(
                                    color: Colors.amber,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  
                  _buildSection('Informacije o računu', [
                    _InfoTile(Icons.email_outlined, 'Email', user?.email ?? ''),
                    _InfoTile(Icons.directions_car_outlined, 'Vozilo',
                        user?.vehiclePlate ?? 'Nije dodano'),
                  ]),
                  const SizedBox(height: 20),
                  
                  _buildSection('Moja aktivnost', [
                    _InfoTile(Icons.local_parking_rounded, 'Ukupno parkinga',
                        '${user?.totalParkings ?? 0}'),
                    _InfoTile(Icons.timer_outlined, 'Ušteda vremena',
                        '${user?.totalMinutesSaved.toInt() ?? 0} min'),
                    _InfoTile(Icons.eco_outlined, 'CO₂ ušteda',
                        '${user?.totalCO2Saved.toStringAsFixed(1) ?? 0} kg'),
                  ]),
                  const SizedBox(height: 20),
                  
                  _buildSection('Omiljeno', [
                    _ActionTile(Icons.favorite_border_rounded, 'Omiljeni parkinzi',
                        () => Navigator.pushNamed(context, '/favorites')),
                  ]),
                  const SizedBox(height: 20),
                  
                  _buildSection('Podešavanja', [
                    _ActionTile(Icons.notifications_outlined, 'Notifikacije',
                        () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const NotificationsSettingsScreen()))),
                    _ActionTile(Icons.lock_outline, 'Sigurnost i privatnost',
                        () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const SecurityScreen()))),
                    _ActionTile(Icons.help_outline_rounded, 'Pomoć',
                        () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const HelpScreen()))),
                  ]),
                  if (user?.premium != true) ...[
                    const SizedBox(height: 20),
                    _buildPremiumCard(context),
                  ],
                  const SizedBox(height: 24),
                  CustomButton(
                    label: 'Odjavi se',
                    outlined: true,
                    icon: Icons.logout_rounded,
                    onPressed: () async {
                      await context.read<UserProvider>().logout();
                      if (context.mounted) {
                        context.read<NotificationProvider>().disconnect();
                        Navigator.pushNamedAndRemoveUntil(
                            context, '/login', (_) => false);
                      }
                    },
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(title,
              style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3)),
        ),
        GlassCard(
          radius: 18,
          blur: 14,
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildPremiumCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.auroraGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        boxShadow: AppTheme.glowShadow(AppTheme.accentBlue, blur: 24, opacity: 0.3),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Icon(Icons.workspace_premium_rounded,
                  color: Colors.amber, size: 28),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nadogradi na Premium',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
                    Text('Rezervacije, prioritet, bez reklama',
                        style: TextStyle(
                            color: AppTheme.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppTheme.border),
          const SizedBox(height: 12),
          const Row(
            children: [
              _PremiumFeature('📅 Rezervacije'),
              _PremiumFeature('📊 Napredna statistika'),
            ],
          ),
          const SizedBox(height: 8),
          const Row(
            children: [
              _PremiumFeature('🔔 Pametne notifikacije'),
              _PremiumFeature('⚡ Prioritet parkinga'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PremiumCheckoutScreen()),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Aktiviraj Premium — 4.99 KM/mj',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textMuted, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
          ),
          Text(value,
              style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile(this.icon, this.label, this.onTap);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.textMuted, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Text(label,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 18),
          ],
        ),
      ),
    );
  }
}

class _PremiumFeature extends StatelessWidget {
  final String text;
  const _PremiumFeature(this.text);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(text,
          style:
              const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../services/session_store.dart';
import '../widgets/glass_card.dart';
import '../providers/notification_provider.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  State<NotificationsSettingsScreen> createState() => _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState extends State<NotificationsSettingsScreen> {
  Map<String, bool> _prefs = {
    'freeSpot': true,
    'reservation': true,
    'promotions': false,
    'chat': true,
  };
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await NotificationPrefsStore.load();
    if (mounted) setState(() {
      _prefs = loaded;
      _loading = false;
    });
  }

  Future<void> _set(String key, bool value) async {
    setState(() => _prefs[key] = value);
    await NotificationPrefsStore.setValue(key, value);
    if (mounted) await context.read<NotificationProvider>().refreshPrefs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Notifikacije'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Obavijesti koje želiš primati',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  GlassCard(
                    radius: 18,
                    blur: 14,
                    child: Column(
                      children: [
                        _switchTile(
                          icon: Icons.local_parking_rounded,
                          title: 'Slobodno mjesto u blizini',
                          subtitle: 'Kad se oslobodi mjesto na omiljenom parkingu',
                          value: _prefs['freeSpot']!,
                          onChanged: (v) => _set('freeSpot', v),
                        ),
                        const Divider(color: AppTheme.border, height: 1),
                        _switchTile(
                          icon: Icons.event_available_rounded,
                          title: 'Podsjetnik za rezervaciju',
                          subtitle: 'Prije isteka rezervisanog termina',
                          value: _prefs['reservation']!,
                          onChanged: (v) => _set('reservation', v),
                        ),
                        const Divider(color: AppTheme.border, height: 1),
                        _switchTile(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: 'Poruke iz chata',
                          subtitle: 'Nova poruka od parking administratora',
                          value: _prefs['chat']!,
                          onChanged: (v) => _set('chat', v),
                        ),
                        const Divider(color: AppTheme.border, height: 1),
                        _switchTile(
                          icon: Icons.local_offer_outlined,
                          title: 'Promocije i akcije',
                          subtitle: 'Popusti i novosti o aplikaciji',
                          value: _prefs['promotions']!,
                          onChanged: (v) => _set('promotions', v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Notifikacije stižu u realnom vremenu preko WebSocket '
                    'konekcije dok je aplikacija otvorena (zvonce na '
                    'početnoj stranici). Isključivanjem kategorije ovdje, '
                    'ta vrsta notifikacija se više neće prikazivati.',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textMuted, size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.accent,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/glass_card.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faqs = [
    (
      'Kako rezervišem parking mjesto?',
      'Otvori detalje parkinga, dodirni "Rezerviši" i izaberi vrijeme. '
          'Rezervacije su dostupne samo za Premium korisnike.'
    ),
    (
      'Kako postajem Premium korisnik?',
      'Na ekranu profila dodirni "Aktiviraj Premium" i završi (demo) plaćanje. '
          'Premium ti otključava rezervacije, naprednu statistiku i prioritet.'
    ),
    (
      'Kako radi "Nađi moj auto"?',
      'Kad parkiraš, otvori "Nađi moj auto" i sačuvaj trenutnu lokaciju. '
          'Kasnije te AR navigacija vodi nazad do tačno tog mjesta.'
    ),
    (
      'Šta ako je parking pun ili netačan?',
      'Koristi dugme "Prijavi problem" (ikonica sa uzvičnikom) da prijaviš '
          'netačnu dostupnost ili oštećenje na parkingu — administrator će biti obaviješten.'
    ),
    (
      'Kako brišem svoj nalog?',
      'Trenutno brisanje naloga ide preko podrške — pošalji nam email (ispod) '
          'sa zahtjevom i potvrdićemo brisanje unutar nekoliko dana.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Pomoć'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const Text('Često postavljana pitanja',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ..._faqs.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _FaqTile(question: f.$1, answer: f.$2),
              )),
          const SizedBox(height: 24),
          const Text('Kontakt podrška',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          GlassCard(
            radius: 18,
            blur: 14,
            child: Column(
              children: const [
                _ContactRow(icon: Icons.email_outlined, label: 'podrska@smartparking.ba'),
                Divider(color: AppTheme.border, height: 1),
                _ContactRow(icon: Icons.phone_outlined, label: '+387 33 000 000'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final String question;
  final String answer;
  const _FaqTile({required this.question, required this.answer});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 16,
      blur: 12,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(widget.question,
                        style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textMuted),
                  ),
                ],
              ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: double.infinity, height: 0),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(widget.answer, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4)),
                ),
                crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ContactRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.textMuted, size: 20),
          const SizedBox(width: 14),
          Text(label, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
        ],
      ),
    );
  }
}

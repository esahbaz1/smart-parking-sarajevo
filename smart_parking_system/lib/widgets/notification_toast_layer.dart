import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme.dart';
import '../providers/notification_provider.dart';


class NotificationToastLayer extends StatefulWidget {
  final Widget child;
  const NotificationToastLayer({super.key, required this.child});

  @override
  State<NotificationToastLayer> createState() => _NotificationToastLayerState();
}

class _NotificationToastLayerState extends State<NotificationToastLayer> {
  AppNotification? _visible;
  DateTime? _lastHandled;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _handleIncoming(NotificationProvider provider, AppNotification n) {
    _lastHandled = n.receivedAt;
    _hideTimer?.cancel();
    setState(() => _visible = n);
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _visible = null);
    });
    provider.consumeIncoming();
  }

  ({IconData icon, Color color}) _styleFor(String type) {
    switch (type) {
      case 'reservation':
        return (icon: Icons.event_available_rounded, color: AppTheme.accentBlue);
      case 'chat':
        return (icon: Icons.chat_bubble_rounded, color: AppTheme.accent);
      case 'freeSpot':
        return (icon: Icons.local_parking_rounded, color: AppTheme.accentGreen);
      default:
        return (icon: Icons.local_offer_rounded, color: AppTheme.accentAmber);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, _) {
        final incoming = provider.lastIncoming;
        if (incoming != null && incoming.receivedAt != _lastHandled) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _handleIncoming(provider, incoming);
          });
        }

        final style = _visible != null ? _styleFor(_visible!.type) : null;

        return Stack(
          children: [
            widget.child,
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: AnimatedSlide(
                offset: _visible != null ? Offset.zero : const Offset(0, -1.5),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: _visible != null ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: _visible == null
                      ? const SizedBox.shrink()
                      : GestureDetector(
                          onTap: () => setState(() => _visible = null),
                          child: Dismissible(
                            key: ValueKey(_visible!.receivedAt),
                            direction: DismissDirection.up,
                            onDismissed: (_) => setState(() => _visible = null),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppTheme.surface.withOpacity(0.96),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppTheme.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: (style?.color ?? AppTheme.accent).withOpacity(0.25),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: (style?.color ?? AppTheme.accent).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(style?.icon ?? Icons.notifications_rounded,
                                        color: style?.color ?? AppTheme.accent, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(_visible!.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: AppTheme.textPrimary,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 14)),
                                        const SizedBox(height: 2),
                                        Text(_visible!.body,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: AppTheme.textSecondary, fontSize: 12.5)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

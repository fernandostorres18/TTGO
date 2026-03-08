// lib/screens/notifications/notifications_screen.dart
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/data_service.dart';
import '../../models/app_models.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';

// ─── SOUND HELPER ─────────────────────────────────────────────────────────

class SoundHelper {
  static void _playTone(String script) {
    try {
      final el = html.ScriptElement()..text = script;
      html.document.head!.append(el);
      el.remove();
    } catch (_) {}
  }

  static void playNotification() {
    _playTone('''
(function(){try{
  var c=new AudioContext();
  var o=c.createOscillator();var g=c.createGain();
  o.connect(g);g.connect(c.destination);
  o.type='sine';o.frequency.value=880;g.gain.value=0.1;
  o.start(c.currentTime);o.stop(c.currentTime+0.15);
}catch(e){}}());
''');
  }

  static void playSuccess() {
    _playTone('''
(function(){try{
  var c=new AudioContext();
  [523,659].forEach(function(f,i){
    var o=c.createOscillator();var g=c.createGain();
    o.connect(g);g.connect(c.destination);
    o.type='sine';o.frequency.value=f;g.gain.value=0.1;
    o.start(c.currentTime+i*0.15);o.stop(c.currentTime+i*0.15+0.12);
  });
}catch(e){}}());
''');
  }

  static void playAlert() {
    _playTone('''
(function(){try{
  var c=new AudioContext();
  var o=c.createOscillator();var g=c.createGain();
  o.connect(g);g.connect(c.destination);
  o.type='square';o.frequency.value=440;g.gain.value=0.08;
  o.start(c.currentTime);o.stop(c.currentTime+0.3);
}catch(e){}}());
''');
  }
}

// ─── NOTIFICATION BELL WIDGET ─────────────────────────────────────────────

class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});
  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _lastCount = 0;

  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DataService>();
    final unread = ds.currentUserUnreadCount;

    // Play sound when new notifications arrive
    if (unread > _lastCount) {
      _lastCount = unread;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SoundHelper.playNotification();
      });
    } else {
      _lastCount = unread;
    }

    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined, color: Colors.white),
          onPressed: () {
            // Não toca som ao abrir notificações — som só ao receber mensagem
            Navigator.push(
              context, MaterialPageRoute(builder: (_) => const NotificationsScreen()));
          },
        ),
        if (unread > 0)
          Positioned(
            right: 6, top: 6,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: AppTheme.error,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              child: Text(
                unread > 9 ? '9+' : '$unread',
                style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

// ─── NOTIFICATIONS SCREEN ─────────────────────────────────────────────────

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ds = context.watch<DataService>();
    final userId = ds.currentUser!.id;
    final notifications = ds.getNotificationsForUser(userId);

    return Scaffold(
      backgroundColor: AppTheme.surface,
      body: Column(
        children: [
          // Header
          Container(
            decoration: AppTheme.headerGradient,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 16, 12),
                child: Row(
                  children: [
                    if (ModalRoute.of(context)?.canPop ?? false)
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                        padding: EdgeInsets.zero,
                      )
                    else
                      const SizedBox(width: 12),
                    const Icon(Icons.notifications, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Notificações',
                          style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                    ),
                    if (notifications.any((n) => !n.isRead))
                      TextButton(
                        onPressed: () => ds.markAllNotificationsRead(userId),
                        child: const Text('Marcar tudo lido',
                            style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // List
          Expanded(
            child: notifications.isEmpty
                ? const EmptyState(
                    icon: Icons.notifications_none,
                    title: 'Sem notificações',
                    subtitle: 'Você está em dia!',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: notifications.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final n = notifications[i];
                      return _NotificationCard(
                        notification: n,
                        onTap: () => ds.markNotificationRead(n.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationCard({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isUnread ? AppTheme.primary.withValues(alpha: 0.06) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUnread ? AppTheme.primary.withValues(alpha: 0.25) : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _iconColor(notification.type).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(_icon(notification.type), color: _iconColor(notification.type), size: 20),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(notification.title,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: isUnread ? FontWeight.bold : FontWeight.w600,
                        color: AppTheme.textPrimary)),
              ),
              if (isUnread)
                Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 3),
              Text(notification.body,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 4),
              Text(_timeAgo(notification.createdAt),
                  style: const TextStyle(fontSize: 11, color: AppTheme.textHint)),
            ],
          ),
        ),
      ),
    );
  }

  IconData _icon(NotificationType type) {
    switch (type) {
      case NotificationType.newOrder: return Icons.receipt_long;
      case NotificationType.stockReceived: return Icons.move_to_inbox;
      case NotificationType.orderStatus: return Icons.update;
      case NotificationType.lowStock: return Icons.warning_amber;
    }
  }

  Color _iconColor(NotificationType type) {
    switch (type) {
      case NotificationType.newOrder: return AppTheme.primary;
      case NotificationType.stockReceived: return AppTheme.success;
      case NotificationType.orderStatus: return AppTheme.info;
      case NotificationType.lowStock: return AppTheme.warning;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Agora';
    if (diff.inMinutes < 60) return 'Há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Há ${diff.inHours}h';
    if (diff.inDays == 1) return 'Ontem';
    return '${diff.inDays} dias atrás';
  }
}

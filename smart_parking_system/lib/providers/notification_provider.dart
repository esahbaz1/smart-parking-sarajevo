import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../core/constants.dart';
import '../services/session_store.dart';


class AppNotification {
  final String type; 
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime receivedAt;
  bool read;

  AppNotification({
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.receivedAt,
    this.read = false,
  });

  factory AppNotification.fromSocket(Map data) {
    return AppNotification(
      type: (data['type'] ?? 'promotions').toString(),
      title: (data['title'] ?? '').toString(),
      body: (data['body'] ?? '').toString(),
      data: Map<String, dynamic>.from(data['data'] ?? {}),
      receivedAt: DateTime.now(),
    );
  }
}


class NotificationProvider extends ChangeNotifier {
  IO.Socket? _socket;
  final List<AppNotification> _items = [];

  
  AppNotification? _lastIncoming;
  Map<String, bool> _prefs = const {
    'freeSpot': true,
    'reservation': true,
    'promotions': false,
    'chat': true,
  };

  List<AppNotification> get items => List.unmodifiable(_items);
  int get unreadCount => _items.where((n) => !n.read).length;
  AppNotification? get lastIncoming => _lastIncoming;
  bool get isConnected => _socket?.connected ?? false;

  Future<void> connect(String userId) async {
    if (_socket != null) return; 
    _prefs = await NotificationPrefsStore.load();

    _socket = IO.io(
      AppConstants.notificationsWsUrl,
      <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
        'reconnection': true,
        'reconnectionDelay': 3000,
        'reconnectionAttempts': 10,
        'timeout': 5000,
      },
    );

    _socket!.onConnect((_) {
      debugPrint('[Notifikacije] Povezan');
      _socket!.emit('authenticate', {'user_id': userId});
    });

    _socket!.onDisconnect((_) => debugPrint('[Notifikacije] Odspojen'));
    _socket!.onConnectError((e) => debugPrint('[Notifikacije] Greška: $e'));

    _socket!.on('notification', (data) {
      if (data == null) return;
      final n = AppNotification.fromSocket(Map<String, dynamic>.from(data));
      
      if (_prefs[n.type] == false) return;
      _items.insert(0, n);
      _lastIncoming = n;
      notifyListeners();
    });
  }

  Future<void> refreshPrefs() async {
    _prefs = await NotificationPrefsStore.load();
  }

  void markAllRead() {
    for (final n in _items) {
      n.read = true;
    }
    notifyListeners();
  }

  void consumeIncoming() {
    _lastIncoming = null;
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _items.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _socket?.dispose();
    super.dispose();
  }
}

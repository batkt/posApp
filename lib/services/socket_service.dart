// ignore_for_file: avoid_print

import 'dart:async';

import 'package:socket_io_client/socket_io_client.dart';

import 'api_service.dart';
import '../models/pos_session.dart';

/// Real-time branch stock sync — listens for `uldegdelChanged` from posBack Socket.IO.
/// Pair with server `joinBranch` + emits from `models/aguulakh.js`.
class SocketService {
  SocketService._internal();
  static final SocketService instance = SocketService._internal();

  Socket? _socket;
  PosSession? _attachedSession;
  String? _attachedTokenPreview;
  Timer? _debounce;

  final StreamController<void> _uldegdelController =
      StreamController<void>.broadcast();

  /// Debounced pulses when warehouse stock (`uldegdel`) changed for this branch.
  Stream<void> get uldegdelChanged => _uldegdelController.stream;

  bool get isConnected => _socket?.connected == true;

  /// Connect (or reconnect) when [session] and `posApiService.token` are set.
  void syncPosSession(PosSession? session) {
    final token = posApiService.token;
    if (session == null ||
        token == null ||
        token.isEmpty ||
        session.baiguullagiinId.isEmpty ||
        session.salbariinId.isEmpty) {
      _disconnect();
      return;
    }

    final tokenPreview =
        token.length > 12 ? token.substring(token.length - 12) : token;
    final sameSession = _attachedSession?.baiguullagiinId ==
            session.baiguullagiinId &&
        _attachedSession?.salbariinId == session.salbariinId;
    final sameToken = _attachedTokenPreview == tokenPreview;

    if (_socket?.connected == true && sameSession && sameToken) {
      return;
    }

    _disconnect();
    _attachedSession = session;
    _attachedTokenPreview = tokenPreview;

    try {
      _socket = io(
        ApiConfig.socketIoHttpRoot,
        OptionBuilder()
            .enableForceNew()
            .setPath('/api/socket.io')
            .setTransports(['websocket'])
            .enableAutoConnect()
            .setExtraHeaders({'Authorization': 'bearer $token'})
            .build(),
      );

      void joinRoom() {
        _socket!.emit('joinBranch', {
          'baiguullagiinId': session.baiguullagiinId,
          'salbariinId': session.salbariinId,
        });
      }

      _socket!.onConnect((_) => joinRoom());

      _socket!.on('uldegdelChanged', (_) => _pulseDebounced());

      _socket!.onDisconnect((_) {});

      _socket!.onConnectError((dynamic e) {
        if (e != null) print('Socket connect_error: $e');
      });
    } catch (e, st) {
      print('Socket init failed: $e\n$st');
      _socket = null;
    }
  }

  void _pulseDebounced() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!_uldegdelController.isClosed) {
        _uldegdelController.add(null);
      }
    });
  }

  void _disconnect() {
    _debounce?.cancel();
    _debounce = null;
    final old = _attachedSession;
    final s = _socket;
    _socket = null;
    _attachedSession = null;
    _attachedTokenPreview = null;
    if (s != null) {
      try {
        if (old != null && s.connected) {
          s.emit('leaveBranch', {
            'baiguullagiinId': old.baiguullagiinId,
            'salbariinId': old.salbariinId,
          });
        }
        s.dispose();
      } catch (e) {
        print('Socket dispose: $e');
      }
    }
  }

  /// Clear connection (logout).
  void disconnect() => _disconnect();
}

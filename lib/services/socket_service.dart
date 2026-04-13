// ignore_for_file: avoid_print

import 'api_service.dart';

/// Stub SocketService for when socket_io_client is not available
/// To enable real-time features, add socket_io_client to pubspec.yaml:
///   socket_io_client: ^2.0.0
class SocketService {
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  String? _token;
  bool _isConnected = false;

  bool get isConnected => _isConnected;
  bool get isAvailable =>
      false; // Socket not available without socket_io_client

  void initSocket(String? token) {
    _token = token;
    print('Socket initialization requested but socket_io_client not available');
    print('Token would be: $token');
    print('Socket URL: ${ApiConfig.socketUrl}');

    // Simulate connection for demo purposes
    _isConnected = false;
  }

  // POS Events - stub implementations
  void joinBranch(String branchId) {
    print('Would join branch: $branchId');
  }

  void leaveBranch(String branchId) {
    print('Would leave branch: $branchId');
  }

  void emitSale(Map<String, dynamic> saleData) {
    print('Would emit sale: $saleData');
  }

  void onSaleCreated(Function(Map<String, dynamic>) callback) {
    print('Sale listener registered (stub)');
  }

  void onInventoryUpdate(Function(Map<String, dynamic>) callback) {
    print('Inventory listener registered (stub)');
  }

  void onNotification(Function(Map<String, dynamic>) callback) {
    print('Notification listener registered (stub)');
  }

  void disconnect() {
    _isConnected = false;
    _token = null;
    print('Socket disconnected (stub)');
  }

  void reconnect() {
    print('Socket reconnect requested (stub)');
  }
}

final socketService = SocketService();

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class NetworkUsageService extends ChangeNotifier {
  static final NetworkUsageService _instance = NetworkUsageService._internal();
  factory NetworkUsageService() => _instance;
  NetworkUsageService._internal();

  final _storage = const FlutterSecureStorage();
  int _dailyBytes = 0;
  String _lastDate = '';

  int get dailyBytes => _dailyBytes;
  
  double get dailyMB => _dailyBytes / (1024 * 1024);

  Future<void> init() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    final savedDate = await _storage.read(key: 'usage_date');
    final savedBytes = await _storage.read(key: 'usage_bytes');
    
    _lastDate = savedDate ?? today;
    
    if (_lastDate != today) {
      _dailyBytes = 0;
      _lastDate = today;
      await _save();
    } else {
      _dailyBytes = int.tryParse(savedBytes ?? '0') ?? 0;
    }
    notifyListeners();
  }

  void addUsage(int bytes) {
    _dailyBytes += bytes;
    _save();
    notifyListeners();
  }

  Future<void> _save() async {
    await _storage.write(key: 'usage_bytes', value: _dailyBytes.toString());
    await _storage.write(key: 'usage_date', value: _lastDate);
  }

  void resetUsage() {
    _dailyBytes = 0;
    _save();
    notifyListeners();
  }
}

final networkUsageService = NetworkUsageService();

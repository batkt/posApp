import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class Connectivity {
  /// Check if internet connection is available
  /// Returns true by default on web (CORS prevents reliable checking)
  static Future<bool> isOnline() async {
    // On web, return true - actual API call will fail if truly offline
    if (kIsWeb) {
      return true;
    }

    // Mobile: Try DNS lookup to multiple hosts
    final hosts = [
      'google.com',
      'cloudflare.com',
    ];

    for (final host in hosts) {
      try {
        final result = await InternetAddress.lookup(host)
            .timeout(const Duration(seconds: 3));
        if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
          return true;
        }
      } catch (_) {
        continue;
      }
    }

    return false;
  }

  /// Check if a specific server is reachable
  static Future<bool> isServerReachable(String host) async {
    // On web, return true - actual API call will fail if unreachable
    if (kIsWeb) {
      return true;
    }

    try {
      final cleanHost = host
          .replaceAll('https://', '')
          .replaceAll('http://', '')
          .replaceAll('wss://', '')
          .replaceAll('ws://', '')
          .split('/')
          .first
          .split(':')
          .first;

      final result = await InternetAddress.lookup(cleanHost)
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }
}

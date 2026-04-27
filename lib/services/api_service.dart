import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:http/http.dart' as http;

class ApiConfig {
  // Production
  static const String baseUrl = 'https://pos.zevtabs.mn/api';
  static const String posBaseUrl = 'https://pos.zevtabs.mn/api';
  static const String socketUrl = 'wss://pos.zevtabs.mn/';

  /// Socket.IO uses http(s) origin; path is `/api/socket.io` (see [SocketService]).
  static String get socketIoHttpRoot {
    var u = socketUrl.trim();
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    if (u.startsWith('wss://')) return u.replaceFirst('wss://', 'https://');
    if (u.startsWith('ws://')) return u.replaceFirst('ws://', 'http://');
    if (u.startsWith('http')) return u;
    return 'https://$u';
  }

  // Local Development (uncomment for local testing)
  // static const String baseUrl = 'http://192.168.1.241:8080';
  // static const String posBaseUrl = 'http://192.168.1.241:8083';
  // static const String socketUrl = 'ws://192.168.1.241:8080';

  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Duration timeout = const Duration(seconds: 30);
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;

  ApiException(this.message, {this.statusCode, this.code});

  @override
  String toString() => 'ApiException: $message (Code: $statusCode)';
}

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final int? statusCode;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.statusCode,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) parser,
  ) {
    return ApiResponse(
      success: json['success'] ?? json['status'] == 'success',
      data: json['data'] != null ? parser(json['data']) : null,
      message: json['message'] ?? json['error'],
      statusCode: json['statusCode'],
    );
  }
}

class ApiService {
  final String baseUrl;
  String? _token;

  ApiService({String? customBaseUrl})
      : baseUrl = customBaseUrl ?? ApiConfig.baseUrl;

  void setToken(String? token) {
    _token = token;
  }

  void clearToken() {
    _token = null;
  }

  String? get token => _token;

  Map<String, String> _getHeaders() {
    final headers = Map<String, String>.from(ApiConfig.defaultHeaders);
    if (_token != null && _token!.isNotEmpty) {
      headers['Authorization'] = 'bearer $_token';
    }
    return headers;
  }

  void _logHttp(String method, Uri uri, http.Response response) {
    if (!kDebugMode) return;
    final len = response.body.length;
    final head = '[PosHTTP] $method $uri → ${response.statusCode} (${len}b)';
    if (len <= 900) {
      debugPrint('$head\n${response.body}');
      return;
    }
    debugPrint('$head\n${response.body.substring(0, 900)}…');
  }

  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    T Function(dynamic)? parser,
    Map<String, String>? queryParams,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint').replace(
        queryParameters: queryParams,
      );

      final response = await http
          .get(uri, headers: _getHeaders())
          .timeout(ApiConfig.timeout);

      _logHttp('GET', uri, response);
      return _handleResponse(response, parser);
    } on ApiException {
      rethrow;
    } on SocketException catch (e) {
      throw ApiException('Network error: ${e.message}', code: 'NETWORK_ERROR');
    } on FormatException catch (e) {
      throw ApiException('Invalid response format: ${e.message}',
          code: 'FORMAT_ERROR');
    } on TimeoutException catch (_) {
      throw ApiException(
        'Request timed out. Please try again.',
        code: 'TIMEOUT',
      );
    } catch (e) {
      throw ApiException('Unexpected error: $e', code: 'UNKNOWN_ERROR');
    }
  }

  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    required Map<String, dynamic> body,
    T Function(dynamic)? parser,
    Duration? timeout,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');

      final response = await http
          .post(
            uri,
            headers: _getHeaders(),
            body: jsonEncode(body),
          )
          .timeout(timeout ?? ApiConfig.timeout);

      _logHttp('POST', uri, response);
      return _handleResponse(response, parser);
    } on ApiException {
      rethrow;
    } on SocketException catch (e) {
      throw ApiException('Network error: ${e.message}', code: 'NETWORK_ERROR');
    } on FormatException catch (e) {
      throw ApiException('Invalid response format: ${e.message}',
          code: 'FORMAT_ERROR');
    } on TimeoutException catch (_) {
      throw ApiException(
        'Request timed out. Please try again.',
        code: 'TIMEOUT',
      );
    } catch (e) {
      throw ApiException('Unexpected error: $e', code: 'UNKNOWN_ERROR');
    }
  }

  Future<ApiResponse<T>> put<T>(
    String endpoint, {
    required Map<String, dynamic> body,
    T Function(dynamic)? parser,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');

      final response = await http
          .put(
            uri,
            headers: _getHeaders(),
            body: jsonEncode(body),
          )
          .timeout(ApiConfig.timeout);

      _logHttp('PUT', uri, response);
      return _handleResponse(response, parser);
    } on ApiException {
      rethrow;
    } on SocketException catch (e) {
      throw ApiException('Network error: ${e.message}', code: 'NETWORK_ERROR');
    } on FormatException catch (e) {
      throw ApiException('Invalid response format: ${e.message}',
          code: 'FORMAT_ERROR');
    } on TimeoutException catch (_) {
      throw ApiException(
        'Request timed out. Please try again.',
        code: 'TIMEOUT',
      );
    } catch (e) {
      throw ApiException('Unexpected error: $e', code: 'UNKNOWN_ERROR');
    }
  }

  Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    T Function(dynamic)? parser,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');

      final response = await http
          .delete(uri, headers: _getHeaders())
          .timeout(ApiConfig.timeout);

      _logHttp('DELETE', uri, response);
      return _handleResponse(response, parser);
    } on ApiException {
      rethrow;
    } on SocketException catch (e) {
      throw ApiException('Network error: ${e.message}', code: 'NETWORK_ERROR');
    } on FormatException catch (e) {
      throw ApiException('Invalid response format: ${e.message}',
          code: 'FORMAT_ERROR');
    } on TimeoutException catch (_) {
      throw ApiException(
        'Request timed out. Please try again.',
        code: 'TIMEOUT',
      );
    } catch (e) {
      throw ApiException('Unexpected error: $e', code: 'UNKNOWN_ERROR');
    }
  }

  /// posBack [aldaaBarigch] uses `{ success: false, aldaa: "…" }` even with HTTP 500.
  static String? _messageFromErrorBody(String raw) {
    if (raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final m = Map<String, dynamic>.from(decoded);
        for (final k in ['aldaa', 'aldaaniiMsg', 'message', 'error', 'msg']) {
          final v = m[k];
          if (v != null) {
            final s = v.toString().trim();
            if (s.isNotEmpty) return s;
          }
        }
      } else if (decoded is String) {
        final s = decoded.trim();
        if (s.isNotEmpty) return s;
      }
    } catch (_) {}
    return null;
  }

  ApiResponse<T> _handleResponse<T>(
    http.Response response,
    T Function(dynamic)? parser,
  ) {
    final statusCode = response.statusCode;
    final raw = response.body;
    final errMsg = _messageFromErrorBody(raw);

    if (statusCode >= 200 && statusCode < 300) {
      if (raw.isEmpty) {
        return ApiResponse<T>(
          success: true,
          data: null,
          statusCode: statusCode,
        );
      }
      dynamic decoded;
      try {
        decoded = jsonDecode(raw);
      } catch (_) {
        decoded = raw;
      }
      if (decoded is Map && decoded['success'] == false) {
        throw ApiException(
          errMsg ?? 'Request failed',
          statusCode: statusCode,
          code: 'API_ERROR',
        );
      }
      return ApiResponse<T>(
        success: true,
        data: parser != null && decoded != null
            ? parser(decoded)
            : decoded as T?,
        statusCode: statusCode,
      );
    } else if (statusCode == 401) {
      throw ApiException(
        errMsg ?? 'Unauthorized',
        statusCode: statusCode,
        code: 'UNAUTHORIZED',
      );
    } else if (statusCode == 403) {
      throw ApiException(
        errMsg ?? 'Forbidden',
        statusCode: statusCode,
        code: 'FORBIDDEN',
      );
    } else if (statusCode == 404) {
      throw ApiException(
        errMsg ?? 'Not found',
        statusCode: statusCode,
        code: 'NOT_FOUND',
      );
    } else if (statusCode >= 500) {
      throw ApiException(
        errMsg ?? 'Server error',
        statusCode: statusCode,
        code: 'SERVER_ERROR',
      );
    } else {
      throw ApiException(
        errMsg ?? 'Request failed',
        statusCode: statusCode,
        code: 'REQUEST_FAILED',
      );
    }
  }
}

// Global API instances
final apiService = ApiService();
final posApiService = ApiService(customBaseUrl: ApiConfig.posBaseUrl);

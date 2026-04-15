import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiConfig {
  // Production
  static const String baseUrl = 'https://pos.zevtabs.mn/api1';
  static const String posBaseUrl = 'https://pos.zevtabs.mn/api';
  static const String socketUrl = 'wss://pos.zevtabs.mn/';

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

      return _handleResponse(response, parser);
    } on SocketException catch (e) {
      throw ApiException('Network error: ${e.message}', code: 'NETWORK_ERROR');
    } on FormatException catch (e) {
      throw ApiException('Invalid response format: ${e.message}',
          code: 'FORMAT_ERROR');
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

      return _handleResponse(response, parser);
    } on SocketException catch (e) {
      throw ApiException('Network error: ${e.message}', code: 'NETWORK_ERROR');
    } on FormatException catch (e) {
      throw ApiException('Invalid response format: ${e.message}',
          code: 'FORMAT_ERROR');
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

      return _handleResponse(response, parser);
    } on SocketException catch (e) {
      throw ApiException('Network error: ${e.message}', code: 'NETWORK_ERROR');
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

      return _handleResponse(response, parser);
    } on SocketException catch (e) {
      throw ApiException('Network error: ${e.message}', code: 'NETWORK_ERROR');
    } catch (e) {
      throw ApiException('Unexpected error: $e', code: 'UNKNOWN_ERROR');
    }
  }

  ApiResponse<T> _handleResponse<T>(
    http.Response response,
    T Function(dynamic)? parser,
  ) {
    final statusCode = response.statusCode;

    if (statusCode >= 200 && statusCode < 300) {
      final raw = response.body;
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
      return ApiResponse<T>(
        success: true,
        data: parser != null && decoded != null
            ? parser(decoded)
            : decoded as T?,
        statusCode: statusCode,
      );
    } else if (statusCode == 401) {
      throw ApiException('Unauthorized',
          statusCode: statusCode, code: 'UNAUTHORIZED');
    } else if (statusCode == 403) {
      throw ApiException('Forbidden',
          statusCode: statusCode, code: 'FORBIDDEN');
    } else if (statusCode == 404) {
      throw ApiException('Not found',
          statusCode: statusCode, code: 'NOT_FOUND');
    } else if (statusCode >= 500) {
      throw ApiException('Server error',
          statusCode: statusCode, code: 'SERVER_ERROR');
    } else {
      final json = jsonDecode(response.body);
      throw ApiException(
        json['message'] ?? json['error'] ?? 'Request failed',
        statusCode: statusCode,
        code: 'REQUEST_FAILED',
      );
    }
  }
}

// Global API instances
final apiService = ApiService();
final posApiService = ApiService(customBaseUrl: ApiConfig.posBaseUrl);

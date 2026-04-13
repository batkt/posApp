import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import '../models/auth_model.dart';

class ImageService {
  final ApiService _apiService;
  final AuthModel _authModel;

  ImageService({
    ApiService? apiService,
    AuthModel? authModel,
  })  : _apiService = apiService ?? posApiService,
        _authModel = authModel ?? AuthModel();

  /// Get authenticated image URL with JWT token
  String getAuthenticatedImageUrl(String imagePath) {
    return 'https://pos.zevtabs.mn/api/file?path=$imagePath';
  }

  /// Download image with JWT authentication
  Future<ImageResult> downloadImage(String imagePath,
      {String type = 'normal'}) async {
    try {
      final token = _apiService.token;

      if (token == null) {
        return ImageResult.failure('No authentication token available');
      }

      // Build URL with type prefix like React useZurag hook
      final pathWithPrefix = type == 'tmp' ? 'tmp/$imagePath' : imagePath;
      final response = await http.get(
        Uri.parse(getAuthenticatedImageUrl(pathWithPrefix)),
        headers: {
          'Authorization': 'bearer $token',
          'Accept': 'image/*',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return ImageResult.success(
          bytes: response.bodyBytes,
          contentType: response.headers['content-type'] ?? 'image/jpeg',
        );
      } else if (response.statusCode == 401) {
        return ImageResult.failure('Authentication required for image access');
      } else if (response.statusCode == 404) {
        return ImageResult.failure('Image not found');
      } else if (response.statusCode == 500) {
        // Internal Server Error - could be file access issue or server problem
        return ImageResult.failure(
            'Internal server error when accessing image');
      } else {
        return ImageResult.failure(
            'Failed to load image: ${response.statusCode}');
      }
    } catch (e) {
      return ImageResult.failure('Network error: ${e.toString()}');
    }
  }

  /// Load image into memory for display
  Future<MemoryImage?> loadMemoryImage(String imagePath) async {
    final result = await downloadImage(imagePath);

    if (result.success && result.bytes != null) {
      return MemoryImage(result.bytes!);
    }

    return null;
  }

  /// Get image provider for network image with authentication headers
  Future<ImageProvider> getAuthenticatedImageProvider(String imagePath) async {
    final result = await loadMemoryImage(imagePath);

    if (result != null) {
      return result;
    }

    // Fallback to placeholder image
    return const NetworkImage(
        'https://images.unsplash.com/photo-1556742049-0cfed4f6a45d?w=400&h=400&fit=crop');
  }
}

class ImageResult {
  final bool success;
  final Uint8List? bytes;
  final String? contentType;
  final String? error;

  ImageResult({
    required this.success,
    this.bytes,
    this.contentType,
    this.error,
  });

  factory ImageResult.success({
    required Uint8List bytes,
    required String contentType,
  }) {
    return ImageResult(
      success: true,
      bytes: bytes,
      contentType: contentType,
    );
  }

  factory ImageResult.failure(String error) {
    return ImageResult(
      success: false,
      error: error,
    );
  }
}

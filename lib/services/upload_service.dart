import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';

class UploadService {
  final Dio _dio = Dio();

  // API endpoints - replace with actual when available
  static const String _baseUrl = 'https://your-backend-api.com';
  static const String _uploadEndpoint = '/api/upload';
  static const String _documentEndpoint = '/api/documents';

  /// Upload a file to the backend
  Future<Map<String, dynamic>> uploadFile({
    required String filePath,
    required String documentId,
    Map<String, dynamic>? metadata,
    Function(int, int)? onProgress,
  }) async {
    try {
      final file = File(filePath);
      final fileName = file.path.split('/').last;

      // Create form data
      final formData = FormData.fromMap({
        'document': await MultipartFile.fromFile(filePath, filename: fileName),
        'documentId': documentId,
        'metadata': metadata != null ? jsonEncode(metadata) : '{}',
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Send request
      final response = await _dio.post(
        '$_baseUrl$_uploadEndpoint',
        data: formData,
        onSendProgress: (sent, total) {
          if (onProgress != null) {
            onProgress(sent, total);
          }
        },
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
            'Accept': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return response.data;
      } else {
        throw Exception('Upload failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Upload error: $e');
    }
  }

  /// Simulate upload (for testing without backend)
  Future<Map<String, dynamic>> simulateUpload({
    required String filePath,
    required String documentId,
    Map<String, dynamic>? metadata,
    Function(int, int)? onProgress,
  }) async {
    // Simulate upload progress
    for (int i = 0; i <= 100; i += 10) {
      if (onProgress != null) {
        onProgress(i, 100);
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }

    // Return mock response
    return {
      'success': true,
      'message': 'File uploaded successfully',
      'data': {
        'filePath': filePath,
        'documentId': documentId,
        'fileName': filePath.split('/').last,
        'uploadedAt': DateTime.now().toIso8601String(),
        'fileSize': await File(filePath).length(),
        'metadata': metadata ?? {},
      },
    };
  }

  /// Get document status
  Future<Map<String, dynamic>> getDocumentStatus(String documentId) async {
    try {
      final response = await _dio.get(
        '$_baseUrl$_documentEndpoint/$documentId',
        options: Options(headers: {'Accept': 'application/json'}),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception(
          'Failed to get document status: ${response.statusCode}',
        );
      }
    } catch (e) {
      // Return mock data for testing
      return {
        'id': documentId,
        'status': 'processing',
        'createdAt': DateTime.now().toIso8601String(),
        'pages': 1,
      };
    }
  }
}

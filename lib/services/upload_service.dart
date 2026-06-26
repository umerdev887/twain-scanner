import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class UploadService {
  final Dio _dio = Dio();

  // API endpoints - replace with actual when available
  static const String _baseUrl = 'https://your-backend-api.com';
  static const String _uploadEndpoint = '/api/upload';
  static const String _documentEndpoint = '/api/documents';

  /// Save document locally and prepare for upload
  Future<Map<String, dynamic>> saveDocumentLocally({
    required String filePath,
    required String documentId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final file = File(filePath);

      // Check if file exists
      if (!await file.exists()) {
        throw Exception('File does not exist: $filePath');
      }

      // Get file details
      final fileSize = await file.length();
      final fileName = file.path.split('/').last;
      final fileExtension = fileName.split('.').last;

      // Create a copy in the app's document directory for backup
      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(path.join(appDir.path, 'scanned_documents'));

      // Create directory if it doesn't exist
      if (!await backupDir.exists()) {
        await backupDir.create(recursive: true);
      }

      // Create backup copy
      final backupPath = path.join(
        backupDir.path,
        '${DateTime.now().millisecondsSinceEpoch}_$fileName',
      );
      await file.copy(backupPath);

      // Return document info
      return {
        'success': true,
        'message': 'Document saved locally',
        'data': {
          'originalPath': filePath,
          'backupPath': backupPath,
          'fileName': fileName,
          'fileSize': fileSize,
          'fileExtension': fileExtension,
          'documentId': documentId,
          'savedAt': DateTime.now().toIso8601String(),
          'metadata': metadata ?? {},
          'readyForUpload': true,
        },
      };
    } catch (e) {
      throw Exception('Failed to save document locally: $e');
    }
  }

  /// Upload a file to the backend (Ready for future API integration)
  Future<Map<String, dynamic>> uploadFile({
    required String filePath,
    required String documentId,
    Map<String, dynamic>? metadata,
    Function(int, int)? onProgress,
  }) async {
    try {
      final file = File(filePath);

      if (!await file.exists()) {
        throw Exception('File does not exist: $filePath');
      }

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
      'message': 'File uploaded successfully (simulated)',
      'data': {
        'filePath': filePath,
        'documentId': documentId,
        'fileName': filePath.split('/').last,
        'uploadedAt': DateTime.now().toIso8601String(),
        'fileSize': await File(filePath).length(),
        'metadata': metadata ?? {},
        'isSimulated': true,
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

  /// Get list of saved documents
  Future<List<Map<String, dynamic>>> getSavedDocuments() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final backupDir = Directory(path.join(appDir.path, 'scanned_documents'));

      if (!await backupDir.exists()) {
        return [];
      }

      final files = await backupDir.list().toList();
      List<Map<String, dynamic>> documents = [];

      for (var file in files) {
        if (file is File && file.path.endsWith('.pdf')) {
          final stat = await file.stat();
          documents.add({
            'path': file.path,
            'fileName': file.path.split('/').last,
            'size': stat.size,
            'modifiedAt': stat.modified.toIso8601String(),
          });
        }
      }

      // Sort by modified date (newest first)
      documents.sort((a, b) => b['modifiedAt'].compareTo(a['modifiedAt']));

      return documents;
    } catch (e) {
      return [];
    }
  }

  /// Delete a saved document
  Future<bool> deleteDocument(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}

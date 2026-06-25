import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class PdfService {
  /// Save PDF to application documents directory
  Future<String> savePdf(Uint8List pdfData) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final fileName = 'document_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final filePath = path.join(dir.path, fileName);

      final file = File(filePath);
      await file.writeAsBytes(pdfData);

      return filePath;
    } catch (e) {
      throw Exception('Failed to save PDF: $e');
    }
  }

  /// Save PDF with custom path
  Future<String> savePdfToPath(Uint8List pdfData, String filePath) async {
    try {
      final file = File(filePath);
      await file.writeAsBytes(pdfData);
      return filePath;
    } catch (e) {
      throw Exception('Failed to save PDF: $e');
    }
  }

  /// Prepare file for upload
  Future<File> getFileForUpload(String filePath) async {
    return File(filePath);
  }

  /// Get file size
  Future<int> getFileSize(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }

  /// Delete file
  Future<void> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw Exception('Failed to delete file: $e');
    }
  }
}

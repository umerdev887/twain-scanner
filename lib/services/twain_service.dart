import 'dart:typed_data';
import 'package:flutter_twain_scanner/flutter_twain_scanner.dart';
import 'package:flutter_twain_scanner/dynamsoft_service.dart' hide ScannerType;
import '../models/scanner_device.dart';
import '../models/scan_job.dart';
import '../utils/constants.dart';

class TwainService {
  final DynamsoftService _dynamsoftService = DynamsoftService();
  final String _host = AppConstants.defaultHost;

  // Plugin instance for device listing
  final FlutterTwainScanner _plugin = FlutterTwainScanner();

  String? _currentDocId;

  /// Public getter for current document ID
  String? get currentDocumentId => _currentDocId;

  /// List all available scanners
  Future<List<ScannerDevice>> listScanners() async {
    try {
      final scanners = await _dynamsoftService.getDevices(
        _host,
        ScannerType.all.value,
      );

      return scanners.asMap().entries.map((entry) {
        final index = entry.key;
        final scanner = entry.value;
        return ScannerDevice(
          id: '${scanner['device']}_$index',
          name: scanner['name'] ?? 'Unknown Scanner',
          device: scanner['device'] ?? '',
          type: ScannerType.fromValue(scanner['type'] ?? 0),
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to list scanners: $e');
    }
  }

  /// Create a new scan job
  Future<ScanJob> createScanJob({
    required ScannerDevice device,
    required ScanConfig config,
    String? license,
  }) async {
    try {
      final parameters = {
        'license': license ?? AppConstants.defaultLicense,
        'device': device.device,
        'config': config.toJson(),
      };

      final job = await _dynamsoftService.createJob(_host, parameters);
      return ScanJob.fromJson(job);
    } catch (e) {
      throw Exception('Failed to create scan job: $e');
    }
  }

  /// Start scanning and get images
  Future<List<Uint8List>> scanDocument({
    required ScanJob job,
    required ScannerDevice device,
  }) async {
    try {
      // Start scanning
      await _dynamsoftService.updateJob(_host, job.id, {'status': 'RUNNING'});

      // Get images
      final images = await _dynamsoftService.getImageStreams(_host, job.id);

      if (images.isEmpty) {
        throw Exception('No images scanned');
      }

      // Create document if needed
      if (_currentDocId == null || _currentDocId!.isEmpty) {
        final doc = await _dynamsoftService.createDocument(_host, {});
        _currentDocId = doc['uid'];
      }

      // Insert pages
      for (var i = 0; i < images.length; i++) {
        final imageInfo = await _dynamsoftService.getImageInfo(_host, job.id);
        await _dynamsoftService.insertPage(_host, _currentDocId!, {
          'password': '',
          'source': imageInfo['url'],
        });
      }

      // Clean up
      await _dynamsoftService.deleteJob(_host, job.id);

      return images;
    } catch (e) {
      // Clean up on error
      try {
        await _dynamsoftService.deleteJob(_host, job.id);
      } catch (_) {}
      throw Exception('Scan failed: $e');
    }
  }

  /// Get PDF document
  Future<Uint8List?> getPdfDocument() async {
    if (_currentDocId == null || _currentDocId!.isEmpty) {
      return null;
    }
    try {
      return await _dynamsoftService.getDocumentStream(_host, _currentDocId!);
    } catch (e) {
      throw Exception('Failed to get PDF: $e');
    }
  }

  /// Reset document ID
  void resetDocument() {
    _currentDocId = null;
  }

  /// Dispose resources
  void dispose() {
    // Clean up any resources if needed
  }
}

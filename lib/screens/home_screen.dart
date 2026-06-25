import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/twain_service.dart';
import '../services/pdf_service.dart';
import '../services/upload_service.dart';
import '../models/scanner_device.dart';
import '../models/scan_job.dart';
import '../widgets/scanner_list.dart';
import '../widgets/image_preview.dart';
import '../widgets/action_buttons.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TwainService _twainService = TwainService();
  final PdfService _pdfService = PdfService();
  final UploadService _uploadService = UploadService();

  List<ScannerDevice> _devices = [];
  ScannerDevice? _selectedDevice;
  List<Uint8List> _images = [];
  bool _isScanning = false;
  bool _isUploading = false;
  String? _errorMessage;
  String? _savedFilePath;
  String? _currentDocumentId;

  @override
  void dispose() {
    _twainService.dispose();
    super.dispose();
  }

  Future<void> _listScanners() async {
    setState(() {
      _errorMessage = null;
    });

    try {
      final devices = await _twainService.listScanners();
      setState(() {
        _devices = devices;
        if (devices.isNotEmpty) {
          _selectedDevice = devices.first;
        } else {
          _selectedDevice = null;
        }
      });

      if (devices.isEmpty) {
        _showSnackBar('No scanners found', isError: false);
      } else {
        _showSnackBar('Found ${devices.length} scanner(s)');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
      _showSnackBar('Error: ${e.toString()}');
    }
  }

  Future<void> _scanDocument() async {
    if (_selectedDevice == null) {
      _showSnackBar('Please select a scanner first');
      return;
    }

    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    try {
      // Create scan configuration
      final config = ScanConfig(
        showUI: false,
        pixelType: 2,
        resolution: 200,
        feederEnabled: false,
        duplexEnabled: false,
      );

      // Create scan job
      final job = await _twainService.createScanJob(
        device: _selectedDevice!,
        config: config,
      );

      // Perform scan
      final images = await _twainService.scanDocument(
        job: job,
        device: _selectedDevice!,
      );

      // Get document ID
      _currentDocumentId = _twainService.currentDocumentId;

      setState(() {
        _images.insertAll(0, images);
        _isScanning = false;
      });

      _showSnackBar('Scanned ${images.length} page(s)');
    } catch (e) {
      setState(() {
        _isScanning = false;
        _errorMessage = e.toString();
      });
      _showSnackBar('Scan failed: ${e.toString()}');
    }
  }

  Future<void> _savePdf() async {
    if (_images.isEmpty) {
      _showSnackBar('No images to save');
      return;
    }

    try {
      final pdfData = await _twainService.getPdfDocument();
      if (pdfData == null) {
        _showSnackBar('No PDF document available');
        return;
      }

      final filePath = await _pdfService.savePdf(pdfData);
      setState(() {
        _savedFilePath = filePath;
      });
      _showSnackBar('PDF saved to: $filePath', isError: false);
    } catch (e) {
      _showSnackBar('Failed to save PDF: ${e.toString()}');
    }
  }

  Future<void> _uploadDocument() async {
    if (_savedFilePath == null) {
      _showSnackBar('Please save the document as PDF first');
      return;
    }

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      // Prepare file for upload
      final fileSize = await _pdfService.getFileSize(_savedFilePath!);

      // Use simulation for testing (replace with actual upload when backend is ready)
      final result = await _uploadService.simulateUpload(
        filePath: _savedFilePath!,
        documentId: _currentDocumentId ?? 'unknown',
        metadata: {
          'pages': _images.length,
          'scanner': _selectedDevice?.name ?? 'Unknown',
          'timestamp': DateTime.now().toIso8601String(),
        },
        onProgress: (sent, total) {
          // Update progress if needed
          print('Upload progress: $sent/$total');
        },
      );

      if (!mounted) return;

      setState(() {
        _isUploading = false;
      });

      _showUploadSuccessDialog(result, fileSize);
    } catch (e) {
      setState(() {
        _isUploading = false;
        _errorMessage = e.toString();
      });
      _showSnackBar('Upload failed: ${e.toString()}');
    }
  }

  void _showUploadSuccessDialog(Map<String, dynamic> result, int fileSize) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Upload Successful'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Document ready for backend processing.'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📄 ${_savedFilePath?.split('/').last ?? 'document.pdf'}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('📊 Size: ${(fileSize / 1024).toStringAsFixed(2)} KB'),
                  const SizedBox(height: 4),
                  Text('📋 Document ID: ${_currentDocumentId ?? 'N/A'}'),
                  const SizedBox(height: 4),
                  Text('📝 Pages: ${_images.length}'),
                  const SizedBox(height: 8),
                  const Text(
                    'API Endpoint: /api/upload',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const Text(
                    'Method: POST',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const Text(
                    'Content-Type: multipart/form-data',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Reset after upload
              _twainService.resetDocument();
              setState(() {
                _images.clear();
                _savedFilePath = null;
                _currentDocumentId = null;
              });
              _showSnackBar('Document uploaded successfully!', isError: false);
            },
            child: const Text('Done'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Show document status
              _checkDocumentStatus();
            },
            child: const Text('Check Status'),
          ),
        ],
      ),
    );
  }

  Future<void> _checkDocumentStatus() async {
    if (_currentDocumentId == null) {
      _showSnackBar('No document to check');
      return;
    }

    try {
      final status = await _uploadService.getDocumentStatus(
        _currentDocumentId!,
      );
      _showSnackBar(
        'Document status: ${status['status'] ?? 'Unknown'}',
        isError: false,
      );
    } catch (e) {
      _showSnackBar('Failed to check status: $e');
    }
  }

  void _showSnackBar(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TWAIN Scanner'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          // IconButton(
          //   icon: const Icon(Icons.info_outline),
          //   onPressed: _showAboutDialog,
          // ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Error display
              if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Action buttons
              ActionButtons(
                onListScanners: _listScanners,
                onScanDocument: _scanDocument,
                onSavePdf: _savePdf,
                onUpload: _uploadDocument,
                isScanning: _isScanning,
                hasImages: _images.isNotEmpty,
                isUploading: _isUploading,
              ),

              const SizedBox(height: 16),

              // Scanner list
              ScannerList(
                devices: _devices,
                selectedDevice: _selectedDevice,
                onDeviceSelected: (device) {
                  setState(() {
                    _selectedDevice = device;
                  });
                },
              ),

              const SizedBox(height: 16),

              // Image preview
              Expanded(
                child: ImagePreview(
                  images: _images,
                  height: MediaQuery.of(context).size.height * 0.5,
                  onDelete: (index) {
                    setState(() {
                      _images.removeAt(index);
                    });
                  },
                ),
              ),

              // Image count indicator
              if (_images.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Total Pages: ${_images.length}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About TWAIN Scanner'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Flutter TWAIN Scanner App'),
            SizedBox(height: 8),
            Text(
              'This app uses Dynamsoft Service to communicate '
              'with TWAIN-compatible scanners.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 8),
            Text(
              'Make sure Dynamsoft Service is running on your system.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

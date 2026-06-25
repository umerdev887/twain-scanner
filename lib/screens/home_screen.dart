import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/twain_service.dart';
import '../services/pdf_service.dart';
import '../services/upload_service.dart';
import '../models/scanner_device.dart';
import '../models/scan_job.dart';
import '../widgets/scanner_list.dart';
import '../widgets/image_preview.dart';
import '../widgets/action_buttons.dart';
import 'package:url_launcher/url_launcher.dart';

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
          InkWell(
            onTap: _showAboutDialog,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Please Click Here First Before Start Scanning'),
                  SizedBox(width: 6),
                  Icon(Icons.error_outline_rounded, color: Colors.amber),
                  // IconButton(
                  //   icon: const Icon(Icons.error_outline_rounded),
                  //   onPressed: _showAboutDialog,
                  // ),
                ],
              ),
            ),
          ),
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
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Theme.of(context).primaryColor),
            const SizedBox(width: 8),
            const Text('About Scanner'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'TWAIN Scanner App',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'This app uses Dynamsoft Service to communicate '
                'with TWAIN-compatible scanners.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.amber.shade700),
                        const SizedBox(width: 8),
                        const Text(
                          'Required: Dynamsoft Service',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please install Dynamsoft Service on your system to use the scanner.',
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Select your operating system:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Windows Download
              _buildDownloadButton(
                context,
                icon: Icons.window_rounded,
                label: 'Windows',
                subtitle: 'Dynamsoft-Service-Setup.msi',
                url:
                    'https://demo.dynamsoft.com/DwT/DwTResources/dist/DynamsoftServiceSetup.msi',
                color: Colors.blue,
              ),
              const SizedBox(height: 8),
              // macOS Download
              _buildDownloadButton(
                context,
                icon: Icons.apple,
                label: 'macOS',
                subtitle: 'Dynamsoft-Service-Setup.pkg',
                url:
                    'https://demo.dynamsoft.com/DwT/DwTResources/dist/DynamsoftServiceSetup.pkg',
                color: Colors.grey.shade800,
              ),
              const SizedBox(height: 8),
              // Linux DEB Download
              _buildDownloadButton(
                context,
                icon: Icons.code,
                label: 'Linux (DEB)',
                subtitle: 'Dynamsoft-Service-Setup.deb',
                url:
                    'https://demo.dynamsoft.com/DwT/DwTResources/dist/DynamsoftServiceSetup.deb',
                color: Colors.orange,
              ),
              const SizedBox(height: 8),
              // Linux ARM64 Download
              _buildDownloadButton(
                context,
                icon: Icons.code,
                label: 'Linux (ARM64)',
                subtitle: 'Dynamsoft-Service-Setup-arm64.deb',
                url:
                    'https://demo.dynamsoft.com/DwT/DwTResources/dist/DynamsoftServiceSetup-arm64.deb',
                color: Colors.orange.shade700,
              ),
              const SizedBox(height: 8),
              // Linux RPM Download
              _buildDownloadButton(
                context,
                icon: Icons.code,
                label: 'Linux (RPM)',
                subtitle: 'Dynamsoft-Service-Setup.rpm',
                url:
                    'https://demo.dynamsoft.com/DwT/DwTResources/dist/DynamsoftServiceSetup.rpm',
                color: Colors.red.shade700,
              ),
              const SizedBox(height: 12),
              // Package Info Link
              // InkWell(
              //   onTap: () {
              //     _launchUrl('https://pub.dev/packages/flutter_twain_scanner');
              //   },
              //   borderRadius: BorderRadius.circular(8),
              //   child: Container(
              //     padding: const EdgeInsets.all(10),
              //     decoration: BoxDecoration(
              //       color: Colors.blue.shade50,
              //       borderRadius: BorderRadius.circular(8),
              //       border: Border.all(color: Colors.blue.shade200),
              //     ),
              //     child: Row(
              //       children: [
              //         Icon(Icons.public, color: Colors.blue.shade700),
              //         const SizedBox(width: 8),
              //         const Expanded(
              //           child: Text(
              //             '📦 View package on pub.dev',
              //             style: TextStyle(
              //               fontSize: 13,
              //               fontWeight: FontWeight.w500,
              //               color: Colors.blue,
              //             ),
              //           ),
              //         ),
              //         Icon(
              //           Icons.arrow_forward,
              //           color: Colors.blue.shade700,
              //           size: 16,
              //         ),
              //       ],
              //     ),
              //   ),
              // ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.help_outline,
                      color: Colors.grey.shade600,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'After installation, restart the app and click "List Scanners"',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showInstallationGuide();
            },
            icon: const Icon(Icons.help_outline),
            label: const Text('Installation Guide'),
          ),
        ],
      ),
    );
  }

  Widget _buildClickableStep(String number, String text, String url) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: Colors.black87),
                children: [
                  TextSpan(text: text),
                  WidgetSpan(
                    child: InkWell(
                      onTap: () {
                        _launchUrlDirect(url);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.blue.shade300),
                        ),
                        child: Text(
                          url,
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: Colors.blue.shade700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const WidgetSpan(child: SizedBox(width: 4)),
                  WidgetSpan(
                    child: Icon(
                      Icons.open_in_new,
                      size: 14,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _launchUrlDirect(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🌐 Opening URL in browser...'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        if (!mounted) return;
        // Fallback: show copy dialog if can't open
        _showCopyDialog(url);
      }
    } catch (e) {
      if (!mounted) return;
      _showCopyDialog(url);
    }
  }

  void _showCopyDialog(String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unable to Open Browser'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please copy the URL and paste it into your browser:'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(
                url,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _copyToClipboard(url);
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy URL'),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required String url,
    required Color color,
  }) {
    return InkWell(
      onTap: () {
        _launchDownload(url, label);
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
          color: Colors.white,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Download',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _launchDownload(String url, String platform) async {
    try {
      final Uri uri = Uri.parse(url);

      // Check if can launch
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloading $platform Dynamsoft Service...'),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        if (!mounted) return;
        _showManualDownloadDialog(url, platform);
      }
    } catch (e) {
      if (!mounted) return;
      _showManualDownloadDialog(url, platform);
    }
  }

  void _showManualDownloadDialog(String url, String platform) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Download $platform Dynamsoft Service'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Unable to open download automatically. Please copy and paste in Browser download manually:',
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: SelectableText(
                url,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'After downloading, run the installer and follow the setup wizard.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _copyToClipboard(url);
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy URL'),
          ),
        ],
      ),
    );
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text)).then((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('URL copied to clipboard!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    });
  }

  void _showInstallationGuide() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Installation Guide'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'How to install Dynamsoft Service:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildStep('1', 'Download the installer for your OS'),
              _buildStep(
                '2',
                'Run the installer (Dynamsoft-Service-Setup.msi/.pkg/.deb)',
              ),
              _buildStep('3', 'Follow the installation wizard'),
              _buildStep('4', 'Wait for installation to complete'),
              // _buildStep('5', 'Open browser and go to: http://127.0.0.1:18622'),
              _buildClickableStep(
                '5',
                'Open browser and go to: ',
                'http://127.0.0.1:18622',
              ),
              _buildStep('6', 'You should see: "Dynamsoft Service is running"'),
              _buildStep('7', 'Return to this app and click "List Scanners"'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'After installation, restart the app if needed.',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

  Widget _buildStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  // void _showAboutDialog() {
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('About TWAIN Scanner'),
  //       content: const Column(
  //         mainAxisSize: MainAxisSize.min,
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           Text('Flutter TWAIN Scanner App'),
  //           SizedBox(height: 8),
  //           Text(
  //             'This app uses Dynamsoft Service to communicate '
  //             'with TWAIN-compatible scanners.',
  //             style: TextStyle(fontSize: 14),
  //           ),
  //           SizedBox(height: 8),
  //           Text(
  //             'Make sure install Dynamsoft Service is running on your system.',
  //             style: TextStyle(fontSize: 12, color: Colors.grey),
  //           ),
  //         ],
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: const Text('OK'),
  //         ),
  //       ],
  //     ),
  //   );
  // }
}

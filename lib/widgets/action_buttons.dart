import 'package:flutter/material.dart';

class ActionButtons extends StatelessWidget {
  final VoidCallback onListScanners;
  final VoidCallback onScanDocument;
  final VoidCallback onSavePdf;
  final VoidCallback onUpload;
  final bool isScanning;
  final bool hasImages;
  final bool isUploading;

  const ActionButtons({
    super.key,
    required this.onListScanners,
    required this.onScanDocument,
    required this.onSavePdf,
    required this.onUpload,
    this.isScanning = false,
    this.hasImages = false,
    this.isUploading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ElevatedButton.icon(
          onPressed: isScanning ? null : onListScanners,
          icon: const Icon(Icons.refresh),
          label: const Text('List Scanners'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        ElevatedButton.icon(
          onPressed: isScanning ? null : onScanDocument,
          icon: isScanning
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.scanner),
          label: Text(isScanning ? 'Scanning...' : 'Scan Document'),
          style: ElevatedButton.styleFrom(
            backgroundColor: isScanning ? Colors.grey : Colors.blue,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        ElevatedButton.icon(
          onPressed: hasImages && !isScanning ? onSavePdf : null,
          icon: const Icon(Icons.save),
          label: const Text('Save PDF'),
          style: ElevatedButton.styleFrom(
            backgroundColor: hasImages ? Colors.green : Colors.grey,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        ElevatedButton.icon(
          onPressed: hasImages && !isScanning && !isUploading ? onUpload : null,
          icon: isUploading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.cloud_upload),
          label: Text(isUploading ? 'Uploading...' : 'Upload'),
          style: ElevatedButton.styleFrom(
            backgroundColor: hasImages ? Colors.purple : Colors.grey,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}

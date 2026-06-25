import 'package:flutter/material.dart';
import '../models/scanner_device.dart';

class ScannerList extends StatelessWidget {
  final List<ScannerDevice> devices;
  final ScannerDevice? selectedDevice;
  final Function(ScannerDevice) onDeviceSelected;

  const ScannerList({
    super.key,
    required this.devices,
    this.selectedDevice,
    required this.onDeviceSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (devices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            'No scanners found.\nClick "List Scanners" to search.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return DropdownButtonFormField<ScannerDevice>(
      value: selectedDevice,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Select Scanner',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      items: devices.map((device) {
        return DropdownMenuItem(
          value: device,
          child: Row(
            children: [
              const Icon(Icons.print, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(device.name, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (device) {
        if (device != null) {
          onDeviceSelected(device);
        }
      },
    );
  }
}

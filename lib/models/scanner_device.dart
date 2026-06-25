class ScannerDevice {
  final String id;
  final String name;
  final String device;
  final ScannerType type;

  ScannerDevice({
    required this.id,
    required this.name,
    required this.device,
    required this.type,
  });

  factory ScannerDevice.fromJson(Map<String, dynamic> json, int index) {
    return ScannerDevice(
      id: '${json['device']}_$index',
      name: json['name'] ?? 'Unknown Scanner',
      device: json['device'] ?? '',
      type: ScannerType.fromValue(json['type'] ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'device': device, 'type': type.value};
  }
}

enum ScannerType {
  twainScanner(1),
  twainX64Scanner(2),
  all(3);

  final int value;
  const ScannerType(this.value);

  static ScannerType fromValue(int value) {
    switch (value) {
      case 1:
        return ScannerType.twainScanner;
      case 2:
        return ScannerType.twainX64Scanner;
      default:
        return ScannerType.all;
    }
  }
}

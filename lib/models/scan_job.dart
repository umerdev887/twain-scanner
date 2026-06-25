import 'dart:typed_data';

class ScanJob {
  final String id;
  final String deviceId;
  final ScanConfig config;
  ScanStatus status;
  List<Uint8List> images;
  final DateTime createdAt;

  ScanJob({
    required this.id,
    required this.deviceId,
    required this.config,
    this.status = ScanStatus.created,
    this.images = const [],
  }) : createdAt = DateTime.now();

  factory ScanJob.fromJson(Map<String, dynamic> json) {
    return ScanJob(
      id: json['jobuid'] ?? '',
      deviceId: json['device'] ?? '',
      config: ScanConfig.fromJson(json['config'] ?? {}),
      status: ScanStatus.fromString(json['status'] ?? 'CREATED'),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'jobuid': id,
      'device': deviceId,
      'config': config.toJson(),
      'status': status.toString().split('.').last,
    };
  }
}

class ScanConfig {
  final bool showUI;
  final int pixelType;
  final int resolution;
  final bool feederEnabled;
  final bool duplexEnabled;
  final int? pageSize;
  final int? xferCount;

  ScanConfig({
    this.showUI = false,
    this.pixelType = 2,
    this.resolution = 200,
    this.feederEnabled = false,
    this.duplexEnabled = false,
    this.pageSize,
    this.xferCount,
  });

  factory ScanConfig.fromJson(Map<String, dynamic> json) {
    return ScanConfig(
      showUI: json['IfShowUI'] ?? false,
      pixelType: json['PixelType'] ?? 2,
      resolution: json['Resolution'] ?? 200,
      feederEnabled: json['IfFeederEnabled'] ?? false,
      duplexEnabled: json['IfDuplexEnabled'] ?? false,
      pageSize: json['PageSize'],
      xferCount: json['XferCount'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'IfShowUI': showUI,
      'PixelType': pixelType,
      'Resolution': resolution,
      'IfFeederEnabled': feederEnabled,
      'IfDuplexEnabled': duplexEnabled,
      if (pageSize != null) 'PageSize': pageSize,
      if (xferCount != null) 'XferCount': xferCount,
    };
  }
}

enum ScanStatus {
  created,
  running,
  completed,
  failed,
  cancelled;

  static ScanStatus fromString(String value) {
    switch (value.toUpperCase()) {
      case 'CREATED':
        return ScanStatus.created;
      case 'RUNNING':
        return ScanStatus.running;
      case 'COMPLETED':
        return ScanStatus.completed;
      case 'FAILED':
        return ScanStatus.failed;
      case 'CANCELLED':
        return ScanStatus.cancelled;
      default:
        return ScanStatus.created;
    }
  }

  String get displayName {
    switch (this) {
      case ScanStatus.created:
        return 'Created';
      case ScanStatus.running:
        return 'Scanning...';
      case ScanStatus.completed:
        return 'Completed';
      case ScanStatus.failed:
        return 'Failed';
      case ScanStatus.cancelled:
        return 'Cancelled';
    }
  }
}

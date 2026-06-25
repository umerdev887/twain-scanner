class AppConstants {
  // Default host for Dynamsoft Service
  static const String defaultHost = 'http://127.0.0.1:18622';

  // Default license (replace with your own)
  static const String defaultLicense =
      'DLS2eyJoYW5kc2hha2VDb2RlIjoiMTA1ODIwOTMzLU1UQTFPREl3T1RNekxWUnlhV0ZzVUhKdmFnIiwibWFpblNlcnZlclVSTCI6Imh0dHBzOi8vbWRscy5keW5hbXNvZnRvbmxpbmUuY29tLyIsIm9yZ2FuaXphdGlvbklEIjoiMTA1ODIwOTMzIiwic3RhbmRieVNlcnZlclVSTCI6Imh0dHBzOi8vc2Rscy5keW5hbXNvZnRvbmxpbmUuY29tLyIsImNoZWNrQ29kZSI6MTE5MDE5NTA4NX0=';

  // Scanner types
  static const int scannerTypeTwain = 1;
  static const int scannerTypeTwainX64 = 2;
  static const int scannerTypeAll = 3;

  // Default scan settings
  static const int defaultResolution = 200;
  static const int defaultPixelType = 2;
  static const bool defaultShowUI = false;
  static const bool defaultFeederEnabled = false;
  static const bool defaultDuplexEnabled = false;
}

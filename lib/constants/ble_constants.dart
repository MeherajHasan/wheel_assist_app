class BleConstants {
  // BLE device name
  static const String deviceName = 'CarController';

  // Service UUID
  static const String serviceUuid = '12345678-1234-1234-1234-123456789abc';

  // App writes commands to this
  static const String rxCharUuid = '12345678-1234-1234-1234-123456789abd';

  // ESP32 sends feedback to this
  static const String txCharUuid = '12345678-1234-1234-1234-123456789abe';

  static const String deviceMac = '00:70:07:7e:6b:fc';

  // Commands
  static const int cmdStop = 0;
  static const int cmdForward = 1;
  static const int cmdBackward = 2;
  static const int cmdLeft = 3;
  static const int cmdRight = 4;

  // Modes
  static const int modeGyro = 0;
  static const int modeApp = 1;
}

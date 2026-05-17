import 'package:flutter/foundation.dart';

class CarState extends ChangeNotifier {
  // connection
  bool isConnected = false;

  // mode — 0 gyro, 1 app
  int mode = 0;

  // current command
  int currentCommand = 0;

  // speed 0-255
  int speed = 150;

  // tuning
  int turnSlow = 80;
  int speedLeft = 200;
  int speedRight = 200;

  // gyro feedback
  double gyroX = 0.0;
  double gyroY = 0.0;

  bool isScanning = false;
  bool isConnecting = false;

  // voice
  bool isVoiceMode = false;
  String lastWord = '';

  String cameraIp = '';

  void setCameraIp(String val) {
    cameraIp = val;
    notifyListeners();
  }

  void setVoiceMode(bool val) {
    isVoiceMode = val;
    notifyListeners();
  }

  void setLastWord(String val) {
    lastWord = val;
    notifyListeners();
  }

  void setScanning(bool val) {
    isScanning = val;
    notifyListeners();
  }

  void setConnecting(bool val) {
    isConnecting = val;
    notifyListeners();
  }

  void setConnected(bool val) {
    isConnected = val;
    print('setConnected called: $val');
    notifyListeners();
  }

  void setMode(int val) {
    mode = val;
    notifyListeners();
  }

  void setCommand(int val) {
    currentCommand = val;
    notifyListeners();
  }

  void setSpeed(int val) {
    speed = val;
    notifyListeners();
  }

  void setTurnSlow(int val) {
    turnSlow = val;
    notifyListeners();
  }

  void setSpeedLeft(int val) {
    speedLeft = val;
    notifyListeners();
  }

  void setSpeedRight(int val) {
    speedRight = val;
    notifyListeners();
  }

  void updateFeedback({
    required double x,
    required double y,
    required int cmd,
    required int mode,
  }) {
    gyroX = x;
    gyroY = y;
    currentCommand = cmd;
    this.mode = mode;
    notifyListeners();
  }
}

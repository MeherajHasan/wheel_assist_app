import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:wheel_assist/constants/ble_constants.dart';
import 'package:wheel_assist/models/car_state.dart';

class BleService {
  final CarState carState;

  BluetoothDevice? _device;
  BluetoothCharacteristic? _rxChar;
  BluetoothCharacteristic? _txChar;

  StreamSubscription? _scanSub;
  StreamSubscription? _feedbackSub;

  BleService(this.carState);

  //////////////////////////////////////////////////
  // SCAN AND CONNECT
  //////////////////////////////////////////////////

  Future<void> startScan() async {
    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    _scanSub = FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        if (r.device.platformName == BleConstants.deviceName) {
          await FlutterBluePlus.stopScan();
          await _connect(r.device);
          break;
        }
      }
    });
  }

  Future<void> _connect(BluetoothDevice device) async {
    _device = device;
    await device.connect(autoConnect: false, license: License.free);

    device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        carState.setConnected(false);
        carState.setMode(0);
      }
    });

    List<BluetoothService> services = await device.discoverServices();

    for (BluetoothService s in services) {
      if (s.uuid.toString() == BleConstants.serviceUuid) {
        for (BluetoothCharacteristic c in s.characteristics) {
          if (c.uuid.toString() == BleConstants.rxCharUuid) {
            _rxChar = c;
          }
          if (c.uuid.toString() == BleConstants.txCharUuid) {
            _txChar = c;
            await c.setNotifyValue(true);
            _feedbackSub = c.onValueReceived.listen(_onFeedback);
          }
        }
      }
    }

    carState.setConnected(true);
  }

  //////////////////////////////////////////////////
  // FEEDBACK FROM ESP32
  //////////////////////////////////////////////////

  void _onFeedback(List<int> data) {
    try {
      final json = jsonDecode(utf8.decode(data));
      carState.updateFeedback(
        x: (json['x'] as num).toDouble(),
        y: (json['y'] as num).toDouble(),
        cmd: json['cmd'] as int,
        mode: json['mode'] as int,
      );
    } catch (e) {
      // ignore malformed packets
    }
  }

  //////////////////////////////////////////////////
  // SEND COMMAND
  //////////////////////////////////////////////////

  Future<void> sendCommand({
    required int mode,
    required int cmd,
    required int speed,
    int? turnSlow,
    int? speedL,
    int? speedR,
  }) async {
    if (_rxChar == null) return;

    final Map<String, dynamic> payload = {
      'mode': mode,
      'cmd': cmd,
      'speed': speed,
    };

    if (turnSlow != null) payload['turn_slow'] = turnSlow;
    if (speedL != null) payload['speed_l'] = speedL;
    if (speedR != null) payload['speed_r'] = speedR;

    final bytes = utf8.encode(jsonEncode(payload));

    await _rxChar!.write(bytes, withoutResponse: true);
  }

  //////////////////////////////////////////////////
  // DISCONNECT
  //////////////////////////////////////////////////

  Future<void> disconnect() async {
    await _feedbackSub?.cancel();
    await _scanSub?.cancel();
    await _device?.disconnect();
    _rxChar = null;
    _txChar = null;
    _device = null;
  }
}

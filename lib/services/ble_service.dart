import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:wheel_assist/constants/ble_constants.dart';
import 'package:wheel_assist/models/car_state.dart';
import 'package:wheel_assist/services/toast_service.dart';
import 'package:toastification/toastification.dart';

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

  bool _isConnecting = false;
  Future<bool> startScan(BuildContext context) async {
    _isConnecting = false;

    final adapterState = await FlutterBluePlus.adapterState.first;
    if (adapterState != BluetoothAdapterState.on) {
      ToastService.show(
        context,
        title: 'Bluetooth is off',
        description: 'Turn on Bluetooth before connecting to Wheel Assist.',
        type: ToastificationType.warning,
      );
      return false;
    }

    try {
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

      _scanSub = FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult r in results) {
          print('FOUND: ${r.device.platformName} | ${r.device.remoteId}');
          if (r.device.platformName == BleConstants.deviceName &&
              !_isConnecting) {
            _isConnecting = true;
            await FlutterBluePlus.stopScan();
            await _scanSub?.cancel();
            await _connect(r.device);
            break;
          }
        }
      });

      return true;
    } catch (e) {
      ToastService.show(
        context,
        title: 'Bluetooth scan failed',
        description: e.toString(),
        type: ToastificationType.error,
      );
      return false;
    }
  }

  //////////////////////////////////////////////////
  // CONNECT
  //////////////////////////////////////////////////

  Future<void> _connect(BluetoothDevice device) async {
    try {
      _device = device;
      print('Connecting to ${device.platformName}');

      await device.connect(autoConnect: false, license: License.free);
      print('Connected — discovering services');

      device.connectionState.listen((state) {
        print('Connection state: $state');
        if (state == BluetoothConnectionState.disconnected) {
          carState.setConnected(false);
          carState.setMode(0);
        }
      });

      await Future.delayed(const Duration(seconds: 1));

      List<BluetoothService> services = await device.discoverServices();
      print('Services found: ${services.length}');

      for (BluetoothService s in services) {
        print('SERVICE: ${s.uuid.toString()}');
        for (BluetoothCharacteristic c in s.characteristics) {
          print('  CHAR: ${c.uuid.toString()}');

          if (c.uuid.toString() == BleConstants.rxCharUuid) {
            _rxChar = c;
            print('  RX CHAR FOUND');
          }
          if (c.uuid.toString() == BleConstants.txCharUuid) {
            _txChar = c;
            await c.setNotifyValue(true);
            _feedbackSub = c.onValueReceived.listen(_onFeedback);
            print('  TX CHAR FOUND');
          }
        }
      }

      if (_rxChar != null && _txChar != null) {
        print('ALL CHARS FOUND — setting connected');
        carState.setConnected(true);
      } else {
        print('CHARS NOT FOUND — rxChar: $_rxChar  txChar: $_txChar');
      }
    } catch (e) {
      print('CONNECT ERROR: $e');
    }
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
      print('FEEDBACK ERROR: $e');
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
    carState.setConnected(false);
    carState.setMode(0);
  }
}

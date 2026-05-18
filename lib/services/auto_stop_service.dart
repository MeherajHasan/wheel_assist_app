import 'dart:async';
import 'dart:isolate';
import 'package:flutter/services.dart';
import 'package:wheel_assist/constants/ble_constants.dart';
import 'package:wheel_assist/models/car_state.dart';
import 'package:wheel_assist/services/ble_service.dart';
import 'package:wheel_assist/services/camera_service.dart';
import 'package:wheel_assist/services/detection_isolate.dart';

class AutoStopService {
  final CarState carState;
  final BleService bleService;

  final CameraService _cameraService = CameraService();

  StreamSubscription<Uint8List>? _frameSub;

  Isolate? _detectionIsolate;
  SendPort? _detectionSendPort;

  bool _isProcessing = false;
  bool _isRunning = false;
  bool _stopSent = false;

  int _frameCount = 0;
  static const int _detectEveryNFrames = 30;

  Stream<Uint8List>? get frameStream => _cameraService.frameStream;

  AutoStopService({required this.carState, required this.bleService});

  //////////////////////////////////////////////////
  // INIT DETECTION ISOLATE
  //////////////////////////////////////////////////

  Future<void> _initDetectionIsolate() async {
    // load model bytes on main isolate where rootBundle works
    final modelData = await rootBundle.load('assets/best_int8_240.tflite');
    final modelBytes = modelData.buffer.asUint8List(
      modelData.offsetInBytes,
      modelData.lengthInBytes,
    );

    final receivePort = ReceivePort();
    final token = RootIsolateToken.instance!;

    _detectionIsolate = await Isolate.spawn(
      detectionIsolateEntry,
      [receivePort.sendPort, token, modelBytes], // pass bytes too
    );

    final completer = Completer<SendPort>();

    receivePort.listen((message) {
      if (message is SendPort) {
        completer.complete(message);
      } else if (message == 'MODEL_LOADED') {
        print('DETECTION ISOLATE READY');
      } else if (message is String && message.startsWith('MODEL_LOAD_ERROR')) {
        print(message);
      }
    });

    _detectionSendPort = await completer.future;
  }

  //////////////////////////////////////////////////
  // SEND TO DETECTION ISOLATE
  //////////////////////////////////////////////////

  Future<DetectionResponse> _detect(Uint8List jpegBytes) async {
    if (_detectionSendPort == null) return DetectionResponse([]);

    final replyPort = ReceivePort();

    _detectionSendPort!.send({
      'type': 'detect',
      'jpegBytes': jpegBytes,
      'replyPort': replyPort.sendPort,
    });

    final response = await replyPort.first;
    replyPort.close();

    if (response is Map && response['type'] == 'detections') {
      final boxes = <DetectionBox>[];
      final rawBoxes = response['boxes'];
      if (rawBoxes is List) {
        for (final rawBox in rawBoxes) {
          if (rawBox is Map<String, dynamic>) {
            boxes.add(DetectionBox.fromMap(rawBox));
          } else if (rawBox is Map) {
            boxes.add(DetectionBox.fromMap(Map<String, dynamic>.from(rawBox)));
          }
        }
      }
      return DetectionResponse(boxes);
    }

    return DetectionResponse([]);
  }

  //////////////////////////////////////////////////
  // START
  //////////////////////////////////////////////////

  Future<void> start(String ip) async {
    if (_isRunning) return;
    _isRunning = true;

    carState.setCameraIp(ip);

    await _initDetectionIsolate();
    await _cameraService.startStream(ip);

    _frameSub = _cameraService.frameStream?.listen((jpegBytes) {
      _frameCount++;

      // detection every N frames — stream never blocked
      if (_frameCount % _detectEveryNFrames == 0 && !_isProcessing) {
        _frameCount = 0;
        _runDetection(jpegBytes);
      }
    });
  }

  //////////////////////////////////////////////////
  // RUN DETECTION
  //////////////////////////////////////////////////

  void _runDetection(Uint8List jpegBytes) async {
    if (!carState.isAutoStop || _isProcessing || _stopSent) return;

    _isProcessing = true;

    try {
      final response = await _detect(jpegBytes);
      final boxes = response.boxes;
      final shouldStop = boxes.any((b) => b.shouldStop);

      carState.setDetectionBoxes(boxes);

      if (shouldStop && !_stopSent) {
        _stopSent = true;
        carState.setIsStopped(true);

        // fire and forget — highest priority
        bleService
            .sendCommand(
              mode: BleConstants.modeApp,
              cmd: BleConstants.cmdStop,
              speed: carState.speed,
            )
            .catchError((e) => print('STOP CMD ERROR: $e'));

        print('AUTO STOP — object detected, pausing 3s');

        Future.delayed(const Duration(seconds: 3), () {
          if (!_isRunning) return;
          _stopSent = false;
          carState.setIsStopped(false);
          carState.setDetectionBoxes([]);
          print('AUTO STOP — resuming detection');
        });
      }
    } catch (e) {
      print('DETECTION ERROR: $e');
    } finally {
      _isProcessing = false;
    }
  }

  //////////////////////////////////////////////////
  // STOP
  //////////////////////////////////////////////////

  Future<void> stop() async {
    _isRunning = false;

    await _frameSub?.cancel();
    _frameSub = null;

    _detectionIsolate?.kill(priority: Isolate.immediate);
    _detectionIsolate = null;
    _detectionSendPort = null;

    await _cameraService.stopStream();

    carState.setCameraIp('');
    carState.setDetectionBoxes([]);
    carState.setIsStopped(false);
    _stopSent = false;
    _isProcessing = false;
    _frameCount = 0;
  }

  //////////////////////////////////////////////////
  // DISPOSE
  //////////////////////////////////////////////////

  void dispose() async {
    await stop();
  }
}

import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:wheel_assist/constants/ble_constants.dart';
import 'package:wheel_assist/models/car_state.dart';
import 'package:wheel_assist/services/ble_service.dart';
import 'package:wheel_assist/services/camera_service.dart';
import 'package:wheel_assist/services/detection_service.dart';

//////////////////////////////////////////////////
// ISOLATE MESSAGE TYPES
//////////////////////////////////////////////////

class _DecodeRequest {
  final Uint8List bytes;
  final SendPort replyPort;
  _DecodeRequest(this.bytes, this.replyPort);
}

// top level — required for isolate
void _decodeIsolateEntry(SendPort mainSendPort) {
  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  receivePort.listen((message) {
    if (message is _DecodeRequest) {
      final image = img.decodeJpg(message.bytes);
      message.replyPort.send(image);
    }
  });
}

//////////////////////////////////////////////////
// AUTO STOP SERVICE
//////////////////////////////////////////////////

class AutoStopService {
  final CarState carState;
  final BleService bleService;

  final CameraService _cameraService = CameraService();
  final DetectionService _detectionService = DetectionService();

  StreamSubscription<Uint8List>? _frameSub;
  Uint8List? _lastJpegBytes;
  Timer? _detectionTimer;

  bool _isProcessing = false;
  bool _isRunning = false;

  // persistent decode isolate
  Isolate? _decodeIsolate;
  SendPort? _decodeSendPort;

  Stream<Uint8List>? get frameStream => _cameraService.frameStream;

  AutoStopService({required this.carState, required this.bleService});

  //////////////////////////////////////////////////
  // INIT DECODE ISOLATE — created once
  //////////////////////////////////////////////////

  Future<void> _initDecodeIsolate() async {
    final receivePort = ReceivePort();
    _decodeIsolate = await Isolate.spawn(
      _decodeIsolateEntry,
      receivePort.sendPort,
    );
    _decodeSendPort = await receivePort.first as SendPort;
    print('DECODE ISOLATE READY');
  }

  Future<img.Image?> _decodeInIsolate(Uint8List bytes) async {
    if (_decodeSendPort == null) return null;
    final replyPort = ReceivePort();
    _decodeSendPort!.send(_DecodeRequest(bytes, replyPort.sendPort));
    final result = await replyPort.first;
    return result as img.Image?;
  }

  //////////////////////////////////////////////////
  // START
  //////////////////////////////////////////////////

  Future<void> start(String ip) async {
    if (_isRunning) return;
    _isRunning = true;

    carState.setCameraIp(ip);

    await _initDecodeIsolate();
    await _detectionService.loadModel();
    await _cameraService.startStream(ip);

    _frameSub = _cameraService.frameStream?.listen((jpegBytes) {
      _lastJpegBytes = jpegBytes;
    });

    bool _stopSent = false;

    void _restartDetectionTimer() {
      _detectionTimer?.cancel();
      _detectionTimer = Timer.periodic(const Duration(milliseconds: 1000), (
        _,
      ) async {
        if (!carState.isAutoStop) return;
        if (_isProcessing || _lastJpegBytes == null) return;

        _isProcessing = true;
        try {
          final image = await _decodeInIsolate(_lastJpegBytes!);
          if (image != null) {
            final results = await _detectionService.detect(image);
            final shouldStop = results.any((r) => r.shouldStop);

            carState.setDetectionBoxes(
              results
                  .map(
                    (r) => DetectionBox(
                      x: r.x,
                      y: r.y,
                      width: r.width,
                      height: r.height,
                      confidence: r.confidence,
                      shouldStop: r.shouldStop,
                    ),
                  )
                  .toList(),
            );

            if (shouldStop && !_stopSent) {
              _stopSent = true;
              carState.setIsStopped(true);
              _detectionTimer?.cancel();
              _detectionTimer = null;

              bleService
                  .sendCommand(
                    mode: BleConstants.modeApp,
                    cmd: BleConstants.cmdStop,
                    speed: carState.speed,
                  )
                  .catchError((e) => print('STOP CMD ERROR: $e'));

              print('AUTO STOP — pausing detection for 3s');

              Future.delayed(const Duration(seconds: 3), () {
                if (!_isRunning) return;
                _stopSent = false;
                carState.setIsStopped(false);
                carState.setDetectionBoxes([]);
                print('AUTO STOP — resuming detection');
                _restartDetectionTimer();
              });
            }
          }
        } catch (e) {
          print('DETECTION ERROR: $e');
        } finally {
          _isProcessing = false;
        }
      });
    }

    _detectionTimer = Timer.periodic(const Duration(milliseconds: 1000), (
      _,
    ) async {
      if (!carState.isAutoStop) return;
      if (_isProcessing || _lastJpegBytes == null) return;

      _isProcessing = true;
      try {
        final image = await _decodeInIsolate(_lastJpegBytes!);
        if (image != null) {
          final results = await _detectionService.detect(image);
          final shouldStop = results.any((r) => r.shouldStop);

          carState.setDetectionBoxes(
            results
                .map(
                  (r) => DetectionBox(
                    x: r.x,
                    y: r.y,
                    width: r.width,
                    height: r.height,
                    confidence: r.confidence,
                    shouldStop: r.shouldStop,
                  ),
                )
                .toList(),
          );

          if (shouldStop && !_stopSent) {
            // STOP — highest priority, fire immediately
            _stopSent = true;
            carState.setIsStopped(true);

            // pause detection for 3 seconds after stop
            _detectionTimer?.cancel();
            _detectionTimer = null;

            // send stop — fire and forget
            bleService
                .sendCommand(
                  mode: BleConstants.modeApp,
                  cmd: BleConstants.cmdStop,
                  speed: carState.speed,
                )
                .catchError((e) => print('STOP CMD ERROR: $e'));

            print('AUTO STOP — pausing detection for 3s');

            // resume detection after 3 seconds
            Future.delayed(const Duration(seconds: 3), () {
              if (!_isRunning) return;
              _stopSent = false;
              carState.setIsStopped(false);
              carState.setDetectionBoxes([]);
              print('AUTO STOP — resuming detection');
              _restartDetectionTimer();
            });
          }
        }
      } catch (e) {
        print('DETECTION ERROR: $e');
      } finally {
        _isProcessing = false;
      }
    });
  }

  //////////////////////////////////////////////////
  // STOP
  //////////////////////////////////////////////////

  Future<void> stop() async {
    _isRunning = false;
    _detectionTimer?.cancel();
    _detectionTimer = null;
    await _frameSub?.cancel();
    _frameSub = null;
    await _cameraService.stopStream();
    _decodeIsolate?.kill(priority: Isolate.immediate);
    _decodeIsolate = null;
    _decodeSendPort = null;
    carState.setCameraIp('');
    carState.setDetectionBoxes([]);
    carState.setIsStopped(false);
  }

  //////////////////////////////////////////////////
  // DISPOSE
  //////////////////////////////////////////////////

  void dispose() {
    stop();
    _detectionService.dispose();
  }
}

//////////////////////////////////////////////////
// DETECTION BOX MODEL
//////////////////////////////////////////////////

class DetectionBox {
  final double x;
  final double y;
  final double width;
  final double height;
  final double confidence;
  final bool shouldStop;

  DetectionBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.confidence,
    required this.shouldStop,
  });
}

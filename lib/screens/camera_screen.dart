import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import 'package:wheel_assist/constants/ble_constants.dart';
import 'package:wheel_assist/models/car_state.dart';
import 'package:wheel_assist/services/ble_service.dart';
import 'package:wheel_assist/services/camera_service.dart';
import 'package:wheel_assist/services/detection_service.dart';

class CameraScreen extends StatefulWidget {
  final BleService bleService;
  final String cameraIp;

  const CameraScreen({
    super.key,
    required this.bleService,
    required this.cameraIp,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final CameraService _cameraService = CameraService();
  final DetectionService _detectionService = DetectionService();

  Uint8List? _currentFrame;
  Uint8List? _lastJpegBytes;
  List<_DisplayBox> _boxes = [];
  bool _detectionOn = true;
  bool _autoStop = true;
  bool _isStopped = false;
  bool _isProcessing = false;
  Timer? _detectionTimer;

  // isolate helper — decode only for detection
  static img.Image? _decodeFrame(Uint8List bytes) {
    return img.decodeJpg(bytes);
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    print('INIT STARTED');
    await _detectionService.loadModel();
    print('MODEL LOAD DONE');
    await _cameraService.startStream(widget.cameraIp);
    print('STREAM STARTED');

    // UI — just pass bytes directly, zero decode cost
    _cameraService.frameStream?.listen((jpegBytes) {
      if (!mounted) return;
      _lastJpegBytes = jpegBytes;
      setState(() {
        _currentFrame = jpegBytes;
      });
    });

    // detection — separate timer, decodes only when needed
    _detectionTimer = Timer.periodic(const Duration(milliseconds: 800), (
      _,
    ) async {
      if (!_detectionOn || _isProcessing || _lastJpegBytes == null) return;
      _isProcessing = true;

      // decode in isolate — never blocks UI
      final image = await compute(_decodeFrame, _lastJpegBytes!);
      if (image != null) await _runDetection(image);

      _isProcessing = false;
    });
  }

  Future<void> _runDetection(img.Image image) async {
    final results = await _detectionService.detect(image);
    if (!mounted) return;

    final List<_DisplayBox> boxes = results
        .map(
          (r) => _DisplayBox(
            x: r.x,
            y: r.y,
            width: r.width,
            height: r.height,
            confidence: r.confidence,
            shouldStop: r.shouldStop,
          ),
        )
        .toList();

    setState(() => _boxes = boxes);

    if (_autoStop && results.any((r) => r.shouldStop)) {
      if (!_isStopped) {
        _isStopped = true;
        final state = context.read<CarState>();
        await widget.bleService.sendCommand(
          mode: BleConstants.modeApp,
          cmd: BleConstants.cmdStop,
          speed: state.speed,
        );
        print('AUTO STOP — object detected');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Object detected — car stopped'),
              backgroundColor: Colors.redAccent,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } else {
      _isStopped = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'CAMERA',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        actions: [
          Row(
            children: [
              const Text(
                'DETECT',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Switch(
                value: _detectionOn,
                activeColor: Colors.deepOrange,
                onChanged: (val) => setState(() {
                  _detectionOn = val;
                  if (!val) _boxes = [];
                }),
              ),
            ],
          ),
          Row(
            children: [
              const Text(
                'AUTO STOP',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Switch(
                value: _autoStop,
                activeColor: Colors.redAccent,
                onChanged: (val) => setState(() => _autoStop = val),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _currentFrame == null
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: Colors.deepOrange),
                        SizedBox(height: 16),
                        Text(
                          'Connecting to camera...',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return Stack(
                        children: [
                          SizedBox(
                            width: constraints.maxWidth,
                            height: constraints.maxHeight,
                            child: Image.memory(
                              _currentFrame!,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                            ),
                          ),
                          CustomPaint(
                            size: Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            ),
                            painter: _BoxPainter(
                              boxes: _boxes,
                              frameWidth: constraints.maxWidth,
                              frameHeight: constraints.maxHeight,
                            ),
                          ),
                          if (_isStopped)
                            Positioned(
                              top: 16,
                              left: 0,
                              right: 0,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'OBJECT DETECTED — STOPPED',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.black,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Objects: ${_boxes.length}',
                  style: const TextStyle(color: Colors.white54),
                ),
                Text(
                  _boxes.any((b) => b.shouldStop) ? 'STOP ZONE' : 'CLEAR',
                  style: TextStyle(
                    color: _boxes.any((b) => b.shouldStop)
                        ? Colors.redAccent
                        : Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'IP: ${widget.cameraIp}',
                  style: const TextStyle(color: Colors.white24, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _cameraService.dispose();
    _detectionService.dispose();
    super.dispose();
  }
}

class _DisplayBox {
  final double x;
  final double y;
  final double width;
  final double height;
  final double confidence;
  final bool shouldStop;

  _DisplayBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.confidence,
    required this.shouldStop,
  });
}

class _BoxPainter extends CustomPainter {
  final List<_DisplayBox> boxes;
  final double frameWidth;
  final double frameHeight;

  _BoxPainter({
    required this.boxes,
    required this.frameWidth,
    required this.frameHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final box in boxes) {
      final paint = Paint()
        ..color = box.shouldStop ? Colors.red : Colors.greenAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      final left = (box.x - box.width / 2) * frameWidth;
      final top = (box.y - box.height / 2) * frameHeight;
      final right = (box.x + box.width / 2) * frameWidth;
      final bottom = (box.y + box.height / 2) * frameHeight;

      canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), paint);

      final textPainter = TextPainter(
        text: TextSpan(
          text: '${(box.confidence * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            color: box.shouldStop ? Colors.red : Colors.greenAccent,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(left, top - 16));
    }
  }

  @override
  bool shouldRepaint(_BoxPainter old) => old.boxes != boxes;
}

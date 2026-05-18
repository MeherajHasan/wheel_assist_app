import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wheel_assist/models/car_state.dart';
import 'package:wheel_assist/services/auto_stop_service.dart';
import 'package:wheel_assist/services/detection_isolate.dart';

class CameraScreen extends StatefulWidget {
  final AutoStopService autoStopService;
  final String cameraIp;

  const CameraScreen({
    super.key,
    required this.autoStopService,
    required this.cameraIp,
  });

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ValueNotifier<Uint8List?> _frameNotifier = ValueNotifier(null);
  StreamSubscription<Uint8List>? _frameSub;
  int _lastRenderMs = 0;

  @override
  void initState() {
    super.initState();

    _frameSub = widget.autoStopService.frameStream?.listen((jpegBytes) {
      if (!mounted) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - _lastRenderMs >= 100) {
        _lastRenderMs = now;
        _frameNotifier.value = jpegBytes;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();

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
                'AUTO STOP',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              Switch(
                value: state.isAutoStop,
                activeColor: Colors.redAccent,
                onChanged: (val) => state.setAutoStop(val),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ValueListenableBuilder<Uint8List?>(
              valueListenable: _frameNotifier,
              builder: (context, frame, _) {
                if (frame == null) {
                  return const Center(
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
                  );
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    return Stack(
                      children: [
                        SizedBox(
                          width: constraints.maxWidth,
                          height: constraints.maxHeight,
                          child: Image.memory(
                            frame,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
                        ),

                        // draw boxes from state
                        CustomPaint(
                          size: Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          ),
                          painter: _BoxPainter(
                            boxes: state.detectionBoxes.cast<DetectionBox>(),
                            frameWidth: constraints.maxWidth,
                            frameHeight: constraints.maxHeight,
                          ),
                        ),

                        if (state.isStopped)
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
                  'Objects: ${state.detectionBoxes.length}',
                  style: const TextStyle(color: Colors.white54),
                ),
                Text(
                  state.isStopped ? 'STOP ZONE' : 'CLEAR',
                  style: TextStyle(
                    color: state.isStopped
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
    _frameSub?.cancel();
    _frameNotifier.dispose();
    super.dispose();
  }
}

class _BoxPainter extends CustomPainter {
  final List<DetectionBox> boxes;
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

      final tp = TextPainter(
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
      tp.layout();
      tp.paint(canvas, Offset(left, top - 16));
    }
  }

  @override
  bool shouldRepaint(_BoxPainter old) => old.boxes != boxes;
}

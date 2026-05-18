import 'dart:isolate';
import 'dart:typed_data';
import 'dart:math';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart';

//////////////////////////////////////////////////
// MESSAGES
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

  Map<String, dynamic> toMap() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
    'confidence': confidence,
    'shouldStop': shouldStop,
  };

  static DetectionBox fromMap(Map<String, dynamic> map) => DetectionBox(
    x: (map['x'] as num).toDouble(),
    y: (map['y'] as num).toDouble(),
    width: (map['width'] as num).toDouble(),
    height: (map['height'] as num).toDouble(),
    confidence: (map['confidence'] as num).toDouble(),
    shouldStop: map['shouldStop'] as bool,
  );

  double get area => width * height;
  bool get isLarge => area > 0.08;
  bool get isCentered => x > 0.30 && x < 0.70 && y > 0.30 && y < 0.70;
}

class DetectionResponse {
  final List<DetectionBox> boxes;
  DetectionResponse(this.boxes);
}

//////////////////////////////////////////////////
// ISOLATE ENTRY
// receives [SendPort, RootIsolateToken, Uint8List modelBytes]
//////////////////////////////////////////////////

void detectionIsolateEntry(List<dynamic> args) async {
  final SendPort mainSendPort = args[0] as SendPort;
  final RootIsolateToken token = args[1] as RootIsolateToken;
  final Uint8List modelBytes = args[2] as Uint8List;

  BackgroundIsolateBinaryMessenger.ensureInitialized(token);

  final receivePort = ReceivePort();
  mainSendPort.send(receivePort.sendPort);

  Interpreter? interpreter;
  Uint8List? inputBuffer;
  Int8List? outputBuffer;

  const int inputSize = 256;
  const int numAnchors = 1344;
  const double confThr = 0.25;
  const double iouThr = 0.45;

  try {
    final options = InterpreterOptions()..threads = 4;
    interpreter = Interpreter.fromBuffer(modelBytes, options: options);

    print('REAL INPUT:  ${interpreter.getInputTensor(0).shape}');
    print('REAL OUTPUT: ${interpreter.getOutputTensor(0).shape}');
    print('INPUT  TYPE: ${interpreter.getInputTensor(0).type}');
    print('OUTPUT TYPE: ${interpreter.getOutputTensor(0).type}');

    // int8 model — uint8 input, int8 output
    inputBuffer = Uint8List(inputSize * inputSize * 3);
    outputBuffer = Int8List(5 * numAnchors);

    mainSendPort.send('MODEL_LOADED');
    print('DETECTION ISOLATE — model loaded');
  } catch (e) {
    mainSendPort.send('MODEL_LOAD_ERROR: $e');
    return;
  }

  await for (final message in receivePort) {
    if (message is Map && message['type'] == 'detect') {
      final jpegBytes = message['jpegBytes'] as Uint8List?;
      final replyPort = message['replyPort'] as SendPort?;
      if (jpegBytes == null || replyPort == null) continue;

      try {
        final image = img.decodeJpg(jpegBytes);
        if (image == null) {
          replyPort.send({'type': 'detections', 'boxes': []});
          continue;
        }

        // resize to model input size
        final resized = img.copyResize(
          image,
          width: inputSize,
          height: inputSize,
          interpolation: img.Interpolation.nearest,
        );

        // fill uint8 buffer — no normalization for int8 model
        int idx = 0;
        for (int y = 0; y < inputSize; y++) {
          for (int x = 0; x < inputSize; x++) {
            final pixel = resized.getPixel(x, y);
            inputBuffer![idx++] = pixel.r.toInt();
            inputBuffer![idx++] = pixel.g.toInt();
            inputBuffer![idx++] = pixel.b.toInt();
          }
        }

        interpreter!.run(
          inputBuffer!.reshape([1, inputSize, inputSize, 3]),
          outputBuffer!.reshape([1, 5, numAnchors]),
        );

        // print raw int8 output values for first 10 anchors
        print('RAW OUTPUT SAMPLE:');
        for (int i = 0; i < 10; i++) {
          final raw = outputBuffer![4 * numAnchors + i];
          print('  anchor[$i] raw conf = $raw');
        }

        print('INPUT  TYPE: ${interpreter.getInputTensor(0).type}');
        print('OUTPUT TYPE: ${interpreter.getOutputTensor(0).type}');

        // dequantize int8 output → float
        // int8 range: -128 to 127 → add 128 → 0 to 255 → divide by 255
        int aboveThreshold = 0;
        double maxConf = 0.0;

        for (int i = 0; i < numAnchors; i++) {
          final double conf = (outputBuffer![4 * numAnchors + i] + 128) / 255.0;
          if (conf > maxConf) maxConf = conf;
          if (conf > confThr) aboveThreshold++;
        }

        print(
          'MAX CONF: ${maxConf.toStringAsFixed(3)} — ABOVE $confThr: $aboveThreshold boxes',
        );

        final List<DetectionBox> results = [];
        for (int i = 0; i < numAnchors; i++) {
          final double conf = (outputBuffer![4 * numAnchors + i] + 128) / 255.0;
          if (conf < confThr) continue;

          final double cx =
              (outputBuffer![0 * numAnchors + i] + 128) / 255.0 * inputSize;
          final double cy =
              (outputBuffer![1 * numAnchors + i] + 128) / 255.0 * inputSize;
          final double w2 =
              (outputBuffer![2 * numAnchors + i] + 128) / 255.0 * inputSize;
          final double h2 =
              (outputBuffer![3 * numAnchors + i] + 128) / 255.0 * inputSize;

          results.add(
            DetectionBox(
              x: cx / inputSize,
              y: cy / inputSize,
              width: w2 / inputSize,
              height: h2 / inputSize,
              confidence: conf,
              shouldStop: false,
            ),
          );
        }

        final kept = _nms(results, iouThr);

        final finalResults = kept
            .map(
              (b) => DetectionBox(
                x: b.x,
                y: b.y,
                width: b.width,
                height: b.height,
                confidence: b.confidence,
                shouldStop: b.isLarge && b.isCentered,
              ),
            )
            .toList();

        replyPort.send({
          'type': 'detections',
          'boxes': finalResults.map((b) => b.toMap()).toList(),
        });
      } catch (e) {
        print('DETECTION ISOLATE ERROR: $e');
        replyPort.send({'type': 'detections', 'boxes': []});
      }
    }
  }
}

//////////////////////////////////////////////////
// NMS + IOU
//////////////////////////////////////////////////

List<DetectionBox> _nms(List<DetectionBox> boxes, double iouThr) {
  if (boxes.isEmpty) return [];
  boxes.sort((a, b) => b.confidence.compareTo(a.confidence));

  final kept = <DetectionBox>[];
  while (boxes.isNotEmpty) {
    final best = boxes.removeAt(0);
    kept.add(best);
    boxes.removeWhere((b) => _iou(best, b) > iouThr);
  }
  return kept;
}

double _iou(DetectionBox a, DetectionBox b) {
  final ax1 = a.x - a.width / 2;
  final ay1 = a.y - a.height / 2;
  final ax2 = a.x + a.width / 2;
  final ay2 = a.y + a.height / 2;

  final bx1 = b.x - b.width / 2;
  final by1 = b.y - b.height / 2;
  final bx2 = b.x + b.width / 2;
  final by2 = b.y + b.height / 2;

  final interW = max(0.0, min(ax2, bx2) - max(ax1, bx1));
  final interH = max(0.0, min(ay2, by2) - max(ay1, by1));
  final inter = interW * interH;

  return inter / (a.width * a.height + b.width * b.height - inter);
}

import 'dart:math';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class DetectionResult {
  final double x; // center x (0-1)
  final double y; // center y (0-1)
  final double width; // (0-1)
  final double height; // (0-1)
  final double confidence;

  DetectionResult({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.confidence,
  });

  // box area as fraction of total frame
  double get area => width * height;

  // is box large enough (>15% of frame)
  bool get isLarge => area > 0.15;

  // is box center in middle 40% of frame
  bool get isCentered => x > 0.30 && x < 0.70 && y > 0.30 && y < 0.70;

  // stop condition C — large AND centered
  bool get shouldStop => isLarge && isCentered;
}

class DetectionService {
  Interpreter? _interpreter;
  bool _isLoaded = false;

  static const int inputSize = 640;
  static const double confThreshold = 0.5;
  static const double iouThreshold = 0.45;

  //////////////////////////////////////////////////
  // LOAD MODEL
  //////////////////////////////////////////////////

  Future<void> loadModel() async {
    try {
      print('LOADING MODEL...');

      final modelData = await rootBundle.load('assets/best_int8.tflite');
      print('ASSET FOUND — size: ${modelData.lengthInBytes} bytes');

      final buffer = modelData.buffer.asUint8List(
        modelData.offsetInBytes,
        modelData.lengthInBytes,
      );

      _interpreter = await Interpreter.fromBuffer(buffer);
      _isLoaded = true;

      print('MODEL LOADED');
      print('INPUT  shape: ${_interpreter!.getInputTensor(0).shape}');
      print('INPUT  type:  ${_interpreter!.getInputTensor(0).type}');
      print('OUTPUT shape: ${_interpreter!.getOutputTensor(0).shape}');
      print('OUTPUT type:  ${_interpreter!.getOutputTensor(0).type}');
    } catch (e, stack) {
      print('MODEL LOAD ERROR: $e');
      print('STACK: $stack');
    }
  }

  //////////////////////////////////////////////////
  // PREPROCESS FRAME
  //////////////////////////////////////////////////

  List<List<List<List<double>>>> _preprocess(img.Image image) {
    // resize to 640x640
    final resized = img.copyResize(image, width: inputSize, height: inputSize);

    // normalize to 0-1 and reshape to [1, 640, 640, 3]
    final input = List.generate(
      1,
      (_) => List.generate(
        inputSize,
        (y) => List.generate(inputSize, (x) {
          final pixel = resized.getPixel(x, y);
          return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
        }),
      ),
    );

    return input;
  }

  //////////////////////////////////////////////////
  // PARSE OUTPUT
  // YOLOv8 output: [1, 5, 8400]
  // 5 = cx, cy, w, h, confidence
  //////////////////////////////////////////////////

  List<DetectionResult> _parseOutput(List<List<List<double>>> output) {
    final List<DetectionResult> results = [];

    final int numBoxes = output[0][0].length; // 8400

    for (int i = 0; i < numBoxes; i++) {
      final double cx = output[0][0][i];
      final double cy = output[0][1][i];
      final double w = output[0][2][i];
      final double h = output[0][3][i];
      final double conf = output[0][4][i];

      if (conf < confThreshold) continue;

      results.add(
        DetectionResult(
          x: cx / inputSize,
          y: cy / inputSize,
          width: w / inputSize,
          height: h / inputSize,
          confidence: conf,
        ),
      );
    }

    return _nms(results);
  }

  //////////////////////////////////////////////////
  // NON-MAX SUPPRESSION
  //////////////////////////////////////////////////

  List<DetectionResult> _nms(List<DetectionResult> boxes) {
    if (boxes.isEmpty) return [];

    // sort by confidence descending
    boxes.sort((a, b) => b.confidence.compareTo(a.confidence));

    final List<DetectionResult> kept = [];

    while (boxes.isNotEmpty) {
      final best = boxes.removeAt(0);
      kept.add(best);

      boxes.removeWhere((box) => _iou(best, box) > iouThreshold);
    }

    return kept;
  }

  double _iou(DetectionResult a, DetectionResult b) {
    final double ax1 = a.x - a.width / 2;
    final double ay1 = a.y - a.height / 2;
    final double ax2 = a.x + a.width / 2;
    final double ay2 = a.y + a.height / 2;

    final double bx1 = b.x - b.width / 2;
    final double by1 = b.y - b.height / 2;
    final double bx2 = b.x + b.width / 2;
    final double by2 = b.y + b.height / 2;

    final double interX1 = max(ax1, bx1);
    final double interY1 = max(ay1, by1);
    final double interX2 = min(ax2, bx2);
    final double interY2 = min(ay2, by2);

    final double interW = max(0, interX2 - interX1);
    final double interH = max(0, interY2 - interY1);
    final double interArea = interW * interH;

    final double aArea = a.width * a.height;
    final double bArea = b.width * b.height;

    return interArea / (aArea + bArea - interArea);
  }

  //////////////////////////////////////////////////
  // RUN INFERENCE
  //////////////////////////////////////////////////

  Future<List<DetectionResult>> detect(img.Image image) async {
    if (!_isLoaded || _interpreter == null) return [];

    try {
      final input = _preprocess(image);
      final output = List.generate(
        1,
        (_) => List.generate(5, (_) => List.filled(8400, 0.0)),
      );

      _interpreter!.run(input, output);

      return _parseOutput(output);
    } catch (e) {
      print('INFERENCE ERROR: $e');
      return [];
    }
  }

  //////////////////////////////////////////////////
  // DISPOSE
  //////////////////////////////////////////////////

  void dispose() {
    _interpreter?.close();
  }
}

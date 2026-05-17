import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class DetectionResult {
  final double x;
  final double y;
  final double width;
  final double height;
  final double confidence;

  DetectionResult({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.confidence,
  });

  double get area => width * height;

  bool get isLarge => area > 0.08;

  bool get isCentered => x > 0.30 && x < 0.70 && y > 0.30 && y < 0.70;

  bool get shouldStop => isLarge && isCentered;
}

class DetectionService {
  Interpreter? _interpreter;

  bool _isLoaded = false;

  // IMPORTANT CHANGE
  static const int inputSize = 640;

  static const double confThreshold = 0.7;
  static const double iouThreshold = 0.45;

  // PREALLOCATED BUFFERS
  late Float32List _inputBuffer;
  late Float32List _outputBuffer;

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

      final options = InterpreterOptions()..threads = 4;

      _interpreter = await Interpreter.fromBuffer(buffer, options: options);

      _isLoaded = true;

      _inputBuffer = Float32List(1 * inputSize * inputSize * 3);

      _outputBuffer = Float32List(1 * 5 * 8400);

      print('MODEL LOADED');

      print('INPUT  shape: ${_interpreter!.getInputTensor(0).shape}');

      print('INPUT  type: ${_interpreter!.getInputTensor(0).type}');

      print('OUTPUT shape: ${_interpreter!.getOutputTensor(0).shape}');

      print('OUTPUT type: ${_interpreter!.getOutputTensor(0).type}');
    } catch (e, stack) {
      print('MODEL LOAD ERROR: $e');
      print('STACK: $stack');
    }
  }

  //////////////////////////////////////////////////
  // PREPROCESS FRAME
  //////////////////////////////////////////////////

  Float32List _preprocess(img.Image image) {
    final resized = img.copyResize(
      image,
      width: inputSize,
      height: inputSize,
      interpolation: img.Interpolation.nearest,
    );

    int idx = 0;

    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = resized.getPixel(x, y);

        _inputBuffer[idx++] = pixel.r / 255.0;
        _inputBuffer[idx++] = pixel.g / 255.0;
        _inputBuffer[idx++] = pixel.b / 255.0;
      }
    }

    return _inputBuffer;
  }

  //////////////////////////////////////////////////
  // PARSE OUTPUT
  //////////////////////////////////////////////////

  List<DetectionResult> _parseOutput(Float32List output) {
    final List<DetectionResult> results = [];

    for (int i = 0; i < 8400; i++) {
      final double conf = output[4 * 8400 + i];

      if (conf < confThreshold) continue;

      final double cx = output[0 * 8400 + i];
      final double cy = output[1 * 8400 + i];
      final double w = output[2 * 8400 + i];
      final double h = output[3 * 8400 + i];

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
    if (!_isLoaded || _interpreter == null) {
      return [];
    }

    try {
      final input = _preprocess(image);

      final inputBuffer = input.reshape([1, inputSize, inputSize, 3]);

      final outputBuffer = _outputBuffer.reshape([1, 5, 8400]);

      _interpreter!.run(inputBuffer, outputBuffer);

      return _parseOutput(_outputBuffer);
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

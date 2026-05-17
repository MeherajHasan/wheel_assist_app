import 'dart:async';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class CameraService {
  String? _streamUrl;
  bool _isStreaming = false;
  bool _processingFrame = false;

  http.Client? _client;
  StreamSubscription<List<int>>? _streamSubscription;

  StreamController<Uint8List>? _frameController;
  Stream<Uint8List>? get frameStream => _frameController?.stream;

  Future<void> startStream(String ip) async {
    _streamUrl = 'http://$ip:81/stream';
    _isStreaming = true;
    _frameController = StreamController<Uint8List>.broadcast();
    _fetchStream();
  }

  void _fetchStream() async {
    try {
      _client = http.Client();
      final request = http.Request('GET', Uri.parse(_streamUrl!));
      final response = await _client!.send(request);
      final List<int> buffer = [];

      _streamSubscription = response.stream.listen(
        (chunk) {
          if (!_isStreaming) return;

          buffer.addAll(chunk);

          // cap buffer
          if (buffer.length > 100000) {
            buffer.clear();
            return;
          }

          int start = -1;
          int end = -1;

          for (int i = 0; i < buffer.length - 1; i++) {
            if (buffer[i] == 0xFF && buffer[i + 1] == 0xD8) start = i;
            if (buffer[i] == 0xFF && buffer[i + 1] == 0xD9) {
              end = i + 2;
              break;
            }
          }

          if (start != -1 && end != -1 && end > start) {
            final jpegBytes = Uint8List.fromList(buffer.sublist(start, end));
            buffer.removeRange(0, end);

            // drop frame if behind
            if (_processingFrame) return;
            _processingFrame = true;

            if (_frameController != null && !_frameController!.isClosed) {
              _frameController!.add(jpegBytes);
            }

            _processingFrame = false;
          }
        },
        onError: (e) async {
          print('STREAM ERROR: $e');
          await _cleanupStream();
          if (_isStreaming) {
            Future.delayed(const Duration(seconds: 2), _fetchStream);
          }
        },
        onDone: () async {
          print('STREAM DONE');
          await _cleanupStream();
          if (_isStreaming) {
            Future.delayed(const Duration(seconds: 2), _fetchStream);
          }
        },
      );
    } catch (e) {
      print('STREAM FETCH ERROR: $e');
      await _cleanupStream();
      if (_isStreaming) {
        Future.delayed(const Duration(seconds: 2), _fetchStream);
      }
    }
  }

  Future<void> _cleanupStream() async {
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    _client?.close();
    _client = null;
  }

  Future<void> stopStream() async {
    _isStreaming = false;
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    _client?.close();
    _client = null;
    await _frameController?.close();
    _frameController = null;
  }

  void dispose() {
    stopStream();
  }
}

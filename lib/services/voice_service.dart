import 'package:speech_to_text/speech_to_text.dart';
import 'package:wheel_assist/models/car_state.dart';
import 'package:wheel_assist/services/ble_service.dart';
import 'package:wheel_assist/constants/ble_constants.dart';

class VoiceService {
  final CarState carState;
  final BleService bleService;

  final SpeechToText _speech = SpeechToText();

  bool _isInitialized = false;
  DateTime _lastCommandTime = DateTime(0);

  // cooldown between commands in milliseconds
  static const int cooldownMs = 500;

  VoiceService(this.carState, this.bleService);

  //////////////////////////////////////////////////
  // INIT
  //////////////////////////////////////////////////

  Future<bool> init() async {
    _isInitialized = await _speech.initialize(
      onError: (error) {
        print('SPEECH ERROR: $error');
        if (carState.isVoiceMode) {
          _listen(); // restart listening on error
        }
      },
      onStatus: (status) {
        print('SPEECH STATUS: $status');
        // restart listening when done if still in voice mode
        if (status == 'done' && carState.isVoiceMode) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (carState.isVoiceMode) _listen();
          });
        }
      },
    );
    return _isInitialized;
  }

  //////////////////////////////////////////////////
  // TOGGLE VOICE MODE
  //////////////////////////////////////////////////

  Future<void> toggleVoiceMode() async {
    if (!_isInitialized) {
      final ok = await init();
      if (!ok) {
        print('SPEECH NOT AVAILABLE');
        return;
      }
    }

    if (carState.isVoiceMode) {
      // turn off
      await _speech.stop();
      carState.setVoiceMode(false);
      carState.setLastWord('');
    } else {
      // turn on
      carState.setVoiceMode(true);
      _listen();
    }
  }

  //////////////////////////////////////////////////
  // LISTEN
  //////////////////////////////////////////////////

  void _listen() {
    if (!carState.isVoiceMode || !_isInitialized) return;

    _speech.listen(
      onResult: (result) {
        if (result.finalResult) {
          final word = result.recognizedWords.toLowerCase().trim();
          print('HEARD: $word');
          carState.setLastWord(word);
          _matchAndSend(word);
        }
      },
      listenFor: const Duration(seconds: 5),
      pauseFor: const Duration(seconds: 2),
      cancelOnError: false,
      partialResults: false,
    );
  }

  //////////////////////////////////////////////////
  // MATCH AND SEND
  //////////////////////////////////////////////////

  void _matchAndSend(String word) {
    // cooldown check
    final now = DateTime.now();
    if (now.difference(_lastCommandTime).inMilliseconds < cooldownMs) {
      print('COOLDOWN — ignoring: $word');
      return;
    }

    int? cmd;
    int? speedDelta;

    if (word.contains('forward') ||
        word.contains('go') ||
        word.contains('ahead')) {
      cmd = BleConstants.cmdForward;
    } else if (word.contains('backward') ||
        word.contains('back') ||
        word.contains('reverse')) {
      cmd = BleConstants.cmdBackward;
    } else if (word.contains('left')) {
      cmd = BleConstants.cmdLeft;
    } else if (word.contains('right')) {
      cmd = BleConstants.cmdRight;
    } else if (word.contains('stop') ||
        word.contains('halt') ||
        word.contains('pause')) {
      cmd = BleConstants.cmdStop;
    } else if (word.contains('faster') || word.contains('speed up')) {
      speedDelta = 20;
    } else if (word.contains('slower') || word.contains('slow down')) {
      speedDelta = -20;
    }

    if (cmd != null) {
      _lastCommandTime = now;
      carState.setCommand(cmd);
      bleService.sendCommand(
        mode: BleConstants.modeApp,
        cmd: cmd,
        speed: carState.speed,
      );
      print('VOICE CMD SENT: $cmd');
    }

    if (speedDelta != null) {
      _lastCommandTime = now;
      final newSpeed = (carState.speed + speedDelta).clamp(80, 255);
      carState.setSpeed(newSpeed);
      bleService.sendCommand(
        mode: BleConstants.modeApp,
        cmd: carState.currentCommand,
        speed: newSpeed,
      );
      print('VOICE SPEED: $newSpeed');
    }
  }

  //////////////////////////////////////////////////
  // DISPOSE
  //////////////////////////////////////////////////

  void dispose() {
    _speech.stop();
    _speech.cancel();
  }
}

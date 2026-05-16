import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wheel_assist/models/car_state.dart';
import 'package:wheel_assist/services/ble_service.dart';
import 'package:wheel_assist/services/voice_service.dart';
import 'package:wheel_assist/widgets/status_bar.dart';
import 'package:wheel_assist/widgets/mode_toggle.dart';
import 'package:wheel_assist/widgets/speed_slider.dart';
import 'package:wheel_assist/widgets/control_pad.dart';

class HomeScreen extends StatelessWidget {
  final BleService bleService;
  final VoiceService voiceService;

  const HomeScreen({
    super.key,
    required this.bleService,
    required this.voiceService,
  });

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Wheel Assist',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 2,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: state.isScanning || state.isConnecting
                ? Row(
                    children: [
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.deepOrange,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        state.isScanning ? 'Scanning...' : 'Connecting...',
                        style: const TextStyle(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                : TextButton.icon(
                    onPressed: () async {
                      if (state.isConnected) {
                        await bleService.disconnect();
                      } else {
                        await bleService.startScan();
                      }
                    },
                    icon: Icon(
                      state.isConnected
                          ? Icons.bluetooth_connected
                          : Icons.bluetooth,
                      color: state.isConnected
                          ? Colors.greenAccent
                          : Colors.deepOrange,
                    ),
                    label: Text(
                      state.isConnected ? 'Disconnect' : 'Connect',
                      style: TextStyle(
                        color: state.isConnected
                            ? Colors.greenAccent
                            : Colors.deepOrange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // STATUS BAR
                const StatusBar(),
                const SizedBox(height: 24),

                // MODE TOGGLE
                ModeToggle(bleService: bleService),
                const SizedBox(height: 24),

                // VOICE MODE — only in app mode
                if (state.isConnected && state.mode == 1) ...[
                  GestureDetector(
                    onTap: () => voiceService.toggleVoiceMode(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: state.isVoiceMode
                            ? Colors.redAccent
                            : Colors.white10,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: state.isVoiceMode
                              ? Colors.redAccent
                              : Colors.white24,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            state.isVoiceMode ? Icons.mic : Icons.mic_none,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            state.isVoiceMode ? 'VOICE ON' : 'VOICE OFF',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // last recognized word
                  if (state.lastWord.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '"${state.lastWord}"',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],

                // CONTROL PAD — hidden when voice mode active
                if (!state.isVoiceMode) ...[
                  ControlPad(bleService: bleService),
                  const SizedBox(height: 32),
                ],

                // SPEED SLIDER
                SpeedSlider(bleService: bleService),
                const SizedBox(height: 24),

                // TUNING SECTION
                if (state.isConnected) ...[
                  const Divider(color: Colors.white12),
                  const SizedBox(height: 16),
                  const Text(
                    'TUNING',
                    style: TextStyle(
                      color: Colors.white38,
                      letterSpacing: 2,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // TURN SHARPNESS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'TURN ARC',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      Text(
                        '${state.turnSlow}',
                        style: const TextStyle(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: state.turnSlow.toDouble(),
                    min: 0,
                    max: 180,
                    divisions: 36,
                    activeColor: Colors.deepOrange,
                    inactiveColor: Colors.white12,
                    onChangeEnd: (val) async {
                      state.setTurnSlow(val.toInt());
                      await bleService.sendCommand(
                        mode: state.mode,
                        cmd: state.currentCommand,
                        speed: state.speed,
                        turnSlow: val.toInt(),
                      );
                    },
                    onChanged: (val) => state.setTurnSlow(val.toInt()),
                  ),

                  // DRIFT LEFT
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'DRIFT LEFT',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      Text(
                        '${state.speedLeft}',
                        style: const TextStyle(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: state.speedLeft.toDouble(),
                    min: 150,
                    max: 255,
                    divisions: 21,
                    activeColor: Colors.deepOrange,
                    inactiveColor: Colors.white12,
                    onChangeEnd: (val) async {
                      state.setSpeedLeft(val.toInt());
                      await bleService.sendCommand(
                        mode: state.mode,
                        cmd: state.currentCommand,
                        speed: state.speed,
                        speedL: val.toInt(),
                      );
                    },
                    onChanged: (val) => state.setSpeedLeft(val.toInt()),
                  ),

                  // DRIFT RIGHT
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'DRIFT RIGHT',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      Text(
                        '${state.speedRight}',
                        style: const TextStyle(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: state.speedRight.toDouble(),
                    min: 150,
                    max: 255,
                    divisions: 21,
                    activeColor: Colors.deepOrange,
                    inactiveColor: Colors.white12,
                    onChangeEnd: (val) async {
                      state.setSpeedRight(val.toInt());
                      await bleService.sendCommand(
                        mode: state.mode,
                        cmd: state.currentCommand,
                        speed: state.speed,
                        speedR: val.toInt(),
                      );
                    },
                    onChanged: (val) => state.setSpeedRight(val.toInt()),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

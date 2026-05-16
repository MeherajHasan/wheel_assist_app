import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wheel_assist/models/car_state.dart';
import 'package:wheel_assist/services/ble_service.dart';
import 'package:wheel_assist/widgets/status_bar.dart';
import 'package:wheel_assist/widgets/mode_toggle.dart';
import 'package:wheel_assist/widgets/speed_slider.dart';
import 'package:wheel_assist/widgets/control_pad.dart';

class HomeScreen extends StatelessWidget {
  final BleService bleService;

  const HomeScreen({super.key, required this.bleService});

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
          // connect / disconnect button
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: TextButton.icon(
              onPressed: () async {
                if (state.isConnected) {
                  await bleService.disconnect();
                } else {
                  await bleService.startScan();
                }
              },
              icon: Icon(
                state.isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
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
                const SizedBox(height: 32),

                // CONTROL PAD
                ControlPad(bleService: bleService),
                const SizedBox(height: 32),

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

                  // DRIFT CORRECTION
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

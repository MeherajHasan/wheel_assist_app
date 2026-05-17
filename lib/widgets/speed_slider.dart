import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wheel_assist/models/car_state.dart';
import 'package:wheel_assist/constants/ble_constants.dart';
import 'package:wheel_assist/services/ble_service.dart';

class SpeedSlider extends StatelessWidget {
  final BleService bleService;

  const SpeedSlider({super.key, required this.bleService});

  @override
  Widget build(BuildContext context) {
    final state = context.read<CarState>();
    final isConnected = context.select((CarState s) => s.isConnected);
    final mode = context.select((CarState s) => s.mode);
    final speed = context.select((CarState s) => s.speed);
    final currentCommand = context.select((CarState s) => s.currentCommand);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'SPEED',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              '$speed',
              style: const TextStyle(
                color: Colors.deepOrange,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        Slider(
          value: speed.toDouble(),
          min: 80,
          max: 255,
          divisions: 35,
          activeColor: Colors.deepOrange,
          inactiveColor: Colors.white12,
          onChanged: isConnected && mode == BleConstants.modeApp
              ? (val) {
                  state.setSpeed(val.toInt());
                }
              : null,
          onChangeEnd: isConnected && mode == BleConstants.modeApp
              ? (val) async {
                  await bleService.sendCommand(
                    mode: mode,
                    cmd: currentCommand,
                    speed: val.toInt(),
                  );
                }
              : null,
        ),
      ],
    );
  }
}

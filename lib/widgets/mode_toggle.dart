import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wheel_assist/models/car_state.dart';
import 'package:wheel_assist/constants/ble_constants.dart';
import 'package:wheel_assist/services/ble_service.dart';

class ModeToggle extends StatelessWidget {
  final BleService bleService;

  const ModeToggle({super.key, required this.bleService});

  @override
  Widget build(BuildContext context) {
    final state = context.read<CarState>();
    final isConnected = context.select((CarState s) => s.isConnected);
    final mode = context.select((CarState s) => s.mode);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          'GYRO',
          style: TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(width: 12),
        Switch(
          value: mode == BleConstants.modeApp,
          activeColor: Colors.deepOrange,
          onChanged: isConnected
              ? (val) async {
                  final newMode = val
                      ? BleConstants.modeApp
                      : BleConstants.modeGyro;
                  state.setMode(newMode);
                  await bleService.sendCommand(
                    mode: newMode,
                    cmd: BleConstants.cmdStop,
                    speed: state.speed,
                  );
                }
              : null,
        ),
        const SizedBox(width: 12),
        const Text(
          'APP',
          style: TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

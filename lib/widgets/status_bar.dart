import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wheel_assist/models/car_state.dart';

class StatusBar extends StatelessWidget {
  const StatusBar({super.key});

  String _commandName(int cmd) {
    switch (cmd) {
      case 1:
        return 'FORWARD';
      case 2:
        return 'BACKWARD';
      case 3:
        return 'LEFT';
      case 4:
        return 'RIGHT';
      default:
        return 'STOP';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // connection status
          Row(
            children: [
              Icon(
                state.isConnected
                    ? Icons.bluetooth_connected
                    : Icons.bluetooth_disabled,
                color: state.isConnected
                    ? Colors.greenAccent
                    : Colors.redAccent,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                state.isConnected ? 'Connected' : 'Disconnected',
                style: TextStyle(
                  color: state.isConnected
                      ? Colors.greenAccent
                      : Colors.redAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          // current command
          Text(
            _commandName(state.currentCommand),
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),

          // gyro values
          Text(
            'X: ${state.gyroX.toStringAsFixed(1)}  Y: ${state.gyroY.toStringAsFixed(1)}',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

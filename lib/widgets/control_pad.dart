import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wheel_assist/models/car_state.dart';
import 'package:wheel_assist/constants/ble_constants.dart';
import 'package:wheel_assist/services/ble_service.dart';

class ControlPad extends StatelessWidget {
  final BleService bleService;

  const ControlPad({super.key, required this.bleService});

  Future<void> _send(CarState state, int cmd) async {
    if (!state.isConnected || state.mode != BleConstants.modeApp) return;
    state.setCommand(cmd);
    await bleService.sendCommand(
      mode:  state.mode,
      cmd:   cmd,
      speed: state.speed,
    );
  }

  Widget _button({
    required CarState state,
    required int cmd,
    required IconData icon,
    required String label,
  }) {
    final isActive = state.currentCommand == cmd;

    return GestureDetector(
      onTapDown: (_) => _send(state, cmd),
      onTapUp:   (_) => _send(state, BleConstants.cmdStop),
      onTapCancel: () => _send(state, BleConstants.cmdStop),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width:  80,
        height: 80,
        decoration: BoxDecoration(
          color: isActive
              ? Colors.deepOrange
              : Colors.white10,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive
                ? Colors.deepOrange
                : Colors.white24,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
              color: isActive ? Colors.white : Colors.white60,
              size: 28,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : Colors.white60,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<CarState>();

    final disabled = !state.isConnected || state.mode != BleConstants.modeApp;

    return Opacity(
      opacity: disabled ? 0.3 : 1.0,
      child: Column(
        children: [
          // FORWARD
          _button(
            state: state,
            cmd:   BleConstants.cmdForward,
            icon:  Icons.arrow_upward,
            label: 'FWD',
          ),
          const SizedBox(height: 12),

          // LEFT / STOP / RIGHT
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _button(
                state: state,
                cmd:   BleConstants.cmdLeft,
                icon:  Icons.arrow_back,
                label: 'LEFT',
              ),
              const SizedBox(width: 12),

              // STOP button
              GestureDetector(
                onTap: () => _send(state, BleConstants.cmdStop),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width:  80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: state.currentCommand == BleConstants.cmdStop
                        ? Colors.redAccent
                        : Colors.white10,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.redAccent,
                      width: 2,
                    ),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.stop, color: Colors.white, size: 28),
                      SizedBox(height: 4),
                      Text(
                        'STOP',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),
              _button(
                state: state,
                cmd:   BleConstants.cmdRight,
                icon:  Icons.arrow_forward,
                label: 'RIGHT',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // BACKWARD
          _button(
            state: state,
            cmd:   BleConstants.cmdBackward,
            icon:  Icons.arrow_downward,
            label: 'BWD',
          ),
        ],
      ),
    );
  }
}
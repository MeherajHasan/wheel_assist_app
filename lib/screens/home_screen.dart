import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wheel_assist/models/car_state.dart';
import 'package:wheel_assist/screens/about_screen.dart';
import 'package:wheel_assist/screens/camera_screen.dart';
import 'package:wheel_assist/services/auto_stop_service.dart';
import 'package:wheel_assist/services/ble_service.dart';
import 'package:wheel_assist/services/toast_service.dart';
import 'package:wheel_assist/services/voice_service.dart';
import 'package:wheel_assist/widgets/status_bar.dart';
import 'package:wheel_assist/widgets/mode_toggle.dart';
import 'package:wheel_assist/widgets/speed_slider.dart';
import 'package:wheel_assist/widgets/control_pad.dart';

class HomeScreen extends StatefulWidget {
  final BleService bleService;
  final VoiceService voiceService;
  final AutoStopService autoStopService;

  const HomeScreen({
    super.key,
    required this.bleService,
    required this.voiceService,
    required this.autoStopService,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final state = context.read<CarState>();
    final isConnected = context.select((CarState s) => s.isConnected);
    final isScanning = context.select((CarState s) => s.isScanning);
    final isConnecting = context.select((CarState s) => s.isConnecting);
    final cameraIp = context.select((CarState s) => s.cameraIp);
    final isVoiceMode = context.select((CarState s) => s.isVoiceMode);
    final lastWord = context.select((CarState s) => s.lastWord);
    final mode = context.select((CarState s) => s.mode);
    final speed = context.select((CarState s) => s.speed);
    final turnSlow = context.select((CarState s) => s.turnSlow);
    final speedLeft = context.select((CarState s) => s.speedLeft);
    final speedRight = context.select((CarState s) => s.speedRight);
    final currentCommand = context.select((CarState s) => s.currentCommand);

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
          IconButton(
            icon: const Icon(Icons.people_outline, color: Colors.white70),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: isScanning || isConnecting
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
                        isScanning ? 'Scanning...' : 'Connecting...',
                        style: const TextStyle(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  )
                : TextButton.icon(
                    onPressed: () async {
                      if (isConnected) {
                        await widget.bleService.disconnect();
                        ToastService.show(context, title: "Disconnecting");
                      } else {
                        final started = await widget.bleService.startScan(
                          context,
                        );
                        if (started) {
                          ToastService.show(context, title: "Scanning");
                        }
                      }
                    },
                    icon: Icon(
                      isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                      color: isConnected
                          ? Colors.greenAccent
                          : Colors.deepOrange,
                    ),
                    label: Text(
                      isConnected ? 'Disconnect' : 'Connect',
                      style: TextStyle(
                        color: isConnected
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
                // CAMERA BUTTON
                if (isConnected) ...[
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () {
                          if (cameraIp.isEmpty) {
                            _showIpDialog(context, state);
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CameraScreen(
                                  autoStopService: widget.autoStopService,
                                  cameraIp: cameraIp,
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.videocam),
                        label: const Text('CAMERA'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // auto stop toggle
                      Row(
                        children: [
                          const Text(
                            'AUTO STOP',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          Switch(
                            value: context.select((CarState s) => s.isAutoStop),
                            activeColor: Colors.redAccent,
                            onChanged: (val) => state.setAutoStop(val),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                // STATUS BAR
                const StatusBar(),
                const SizedBox(height: 24),

                // MODE TOGGLE
                ModeToggle(bleService: widget.bleService),
                const SizedBox(height: 24),

                // VOICE MODE — only in app mode
                if (isConnected && mode == 1) ...[
                  GestureDetector(
                    onTap: () => widget.voiceService.toggleVoiceMode(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isVoiceMode ? Colors.redAccent : Colors.white10,
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: isVoiceMode
                              ? Colors.redAccent
                              : Colors.white24,
                          width: 2,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isVoiceMode ? Icons.mic : Icons.mic_none,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isVoiceMode ? 'VOICE ON' : 'VOICE OFF',
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
                  if (lastWord.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '"$lastWord"',
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
                if (!isVoiceMode) ...[
                  ControlPad(bleService: widget.bleService),
                  const SizedBox(height: 32),
                ],

                // SPEED SLIDER
                SpeedSlider(bleService: widget.bleService),
                const SizedBox(height: 24),

                // TUNING SECTION
                if (isConnected) ...[
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
                        '$turnSlow',
                        style: const TextStyle(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: turnSlow.toDouble(),
                    min: 0,
                    max: 180,
                    divisions: 36,
                    activeColor: Colors.deepOrange,
                    inactiveColor: Colors.white12,
                    onChangeEnd: (val) async {
                      state.setTurnSlow(val.toInt());
                      await widget.bleService.sendCommand(
                        mode: mode,
                        cmd: currentCommand,
                        speed: speed,
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
                        '$speedLeft',
                        style: const TextStyle(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: speedLeft.toDouble(),
                    min: 150,
                    max: 255,
                    divisions: 21,
                    activeColor: Colors.deepOrange,
                    inactiveColor: Colors.white12,
                    onChangeEnd: (val) async {
                      state.setSpeedLeft(val.toInt());
                      await widget.bleService.sendCommand(
                        mode: mode,
                        cmd: currentCommand,
                        speed: speed,
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
                        '$speedRight',
                        style: const TextStyle(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: speedRight.toDouble(),
                    min: 150,
                    max: 255,
                    divisions: 21,
                    activeColor: Colors.deepOrange,
                    inactiveColor: Colors.white12,
                    onChangeEnd: (val) async {
                      state.setSpeedRight(val.toInt());
                      await widget.bleService.sendCommand(
                        mode: mode,
                        cmd: currentCommand,
                        speed: speed,
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

  void _showIpDialog(BuildContext context, CarState state) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Camera IP', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: '192.168.1.100',
            hintStyle: TextStyle(color: Colors.white38),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'CANCEL',
              style: TextStyle(color: Colors.white54),
            ),
          ),

          TextButton(
            onPressed: () async {
              final ip = controller.text.trim();
              state.setCameraIp(ip);
              Navigator.pop(context);
              await widget.autoStopService.start(ip);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CameraScreen(
                    autoStopService: widget.autoStopService,
                    cameraIp: ip,
                  ),
                ),
              );
            },
            child: const Text(
              'CONNECT',
              style: TextStyle(color: Colors.deepOrange),
            ),
          ),
        ],
      ),
    );
  }
}

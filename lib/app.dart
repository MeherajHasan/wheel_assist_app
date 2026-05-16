import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wheel_assist/models/car_state.dart';
import 'package:wheel_assist/services/ble_service.dart';
import 'package:wheel_assist/services/voice_service.dart';
import 'package:wheel_assist/screens/home_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CarState(),
      child: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  late BleService   _bleService;
  late VoiceService _voiceService;

  @override
  void initState() {
    super.initState();
    final carState    = context.read<CarState>();
    _bleService       = BleService(carState);
    _voiceService     = VoiceService(carState, _bleService);
  }

  @override
  void dispose() {
    _bleService.disconnect();
    _voiceService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WheelAssist',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: HomeScreen(
        bleService:   _bleService,
        voiceService: _voiceService,
      ),
    );
  }
}
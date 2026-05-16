import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wheel_assist/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  Permission.microphone;
  Permission.speech;
  runApp(const App());
}

// lib/services/toast_service.dart

import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

class ToastService {
  static void show(
    BuildContext context, {
    required String title,
    String? description,
    ToastificationType type = ToastificationType.info,
  }) {
    toastification.show(
      context: context,
      type: type,
      style: ToastificationStyle.flat,
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      description: description != null
          ? Text(description, style: const TextStyle(color: Colors.white60))
          : null,
      backgroundColor: const Color(0xFF1C1C1C),
      foregroundColor: Colors.white,
      borderSide: BorderSide(color: Colors.white12),
      primaryColor: _accentColor(type),
      borderRadius: BorderRadius.circular(14),
      alignment: Alignment.topCenter,
      autoCloseDuration: const Duration(seconds: 3),
      showProgressBar: false,
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    );
  }

  static Color _accentColor(ToastificationType type) {
    switch (type) {
      case ToastificationType.success:
        return Colors.greenAccent;
      case ToastificationType.error:
        return Colors.redAccent;
      case ToastificationType.warning:
        return Colors.deepOrange;
      case ToastificationType.info:
      default:
        return const Color(0xFF0066FF);
    }
  }
}

// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'config.dart';

void initWebThemeListener(VoidCallback onUpdate) {
  html.window.addEventListener('message', (html.Event event) {
    final message = event as html.MessageEvent;
    if (message.data != null && message.data['type'] == 'UPDATE_THEME') {
      try {
        final Map<String, dynamic> themeData = Map<String, dynamic>.from(
          message.data['theme'],
        );
        BrandConfig.active = BrandConfig.fromJson(themeData);
        onUpdate();
      } catch (e) {
        debugPrint('Error updating theme from message: $e');
      }
    }
  });
}

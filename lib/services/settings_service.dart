import 'dart:math';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _kFontSize = 'reader_font_size';
  static const _kFontSizeSet = 'reader_font_size_set';

  Future<double?> getSavedFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    final isSet = prefs.getBool(_kFontSizeSet) ?? false;
    if (!isSet) return null;
    return prefs.getDouble(_kFontSize);
  }

  Future<void> setFontSize(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kFontSize, value);
    await prefs.setBool(_kFontSizeSet, true);
  }

  Future<void> resetFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kFontSize);
    await prefs.setBool(_kFontSizeSet, false);
  }

  static double computeAdaptiveFontSize(BuildContext context) {
    final mq = MediaQuery.of(context);
    final ratio = mq.devicePixelRatio;
    final widthPx = mq.size.width * ratio;
    final heightPx = mq.size.height * ratio;
    final diagPx = sqrt(widthPx * widthPx + heightPx * heightPx);

    final computed = diagPx / 130.0;
    return computed.clamp(13.0, 30.0).roundToDouble();
  }
}

import 'package:flutter/widgets.dart';
import '../services/settings_service.dart';

class SettingsProvider extends ChangeNotifier {
  double fontSize = 17.0;
  bool _fontSizeIsAuto = true;

  final SettingsService _service = SettingsService();

  bool get fontSizeIsAuto => _fontSizeIsAuto;

  Future<void> load() async {
    final saved = await _service.getSavedFontSize();
    if (saved != null) {
      fontSize = saved;
      _fontSizeIsAuto = false;
    }
    notifyListeners();
  }

  Future<void> initFontSize(BuildContext context) async {
    if (!_fontSizeIsAuto) return;
    fontSize = SettingsService.computeAdaptiveFontSize(context);
    notifyListeners();
  }

  Future<void> increaseFontSize() async {
    if (fontSize >= 30) return;
    fontSize = (fontSize + 1).clamp(13.0, 30.0);
    _fontSizeIsAuto = false;
    await _service.setFontSize(fontSize);
    notifyListeners();
  }

  Future<void> decreaseFontSize() async {
    if (fontSize <= 13) return;
    fontSize = (fontSize - 1).clamp(13.0, 30.0);
    _fontSizeIsAuto = false;
    await _service.setFontSize(fontSize);
    notifyListeners();
  }

  Future<void> resetFontSize(BuildContext context) async {
    final adaptive = SettingsService.computeAdaptiveFontSize(context);
    await _service.resetFontSize();
    _fontSizeIsAuto = true;
    fontSize = adaptive;
    notifyListeners();
  }
}

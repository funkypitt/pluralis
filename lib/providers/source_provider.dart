import 'package:flutter/foundation.dart';
import '../models/source.dart';
import '../services/source_service.dart';

class SourceProvider extends ChangeNotifier {
  List<Source> _sources = [];
  List<Source> get sources => _sources;
  List<Source> get activeSources => _sources.where((s) => s.active).toList();

  final SourceService _service = SourceService();

  Future<void> load() async {
    _sources = await _service.loadSources();
    notifyListeners();
  }

  Future<void> toggleSource(String id) async {
    final i = _sources.indexWhere((s) => s.id == id);
    if (i >= 0) {
      _sources[i].active = !_sources[i].active;
      await _service.saveSources(_sources);
      notifyListeners();
    }
  }

  Future<void> addSource(Source source) async {
    await _service.addCustomSource(source);
    await load();
  }

  Future<void> removeSource(String id) async {
    await _service.removeSource(id);
    await load();
  }
}

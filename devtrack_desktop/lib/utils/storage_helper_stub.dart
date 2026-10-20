import 'dart:convert';
import 'dart:io';

final Map<String, String> _memoryStorage = {};
bool _loaded = false;

File _getStorageFile() {
  final appData = Platform.environment['LOCALAPPDATA'] ??
      Platform.environment['APPDATA'] ??
      Platform.environment['USERPROFILE'] ??
      Directory.current.path;
  final dir = Directory('$appData/DevTrack');
  if (!dir.existsSync()) {
    try {
      dir.createSync(recursive: true);
    } catch (_) {}
  }
  return File('${dir.path}/session_cache.json');
}

void _loadIfNeeded() {
  if (_loaded) return;
  _loaded = true;
  try {
    final file = _getStorageFile();
    if (file.existsSync()) {
      final content = file.readAsStringSync();
      if (content.isNotEmpty) {
        final Map<String, dynamic> data = jsonDecode(content);
        data.forEach((k, v) {
          if (v != null) _memoryStorage[k] = v.toString();
        });
      }
    }
  } catch (_) {}
}

void _persist() {
  try {
    final file = _getStorageFile();
    file.writeAsStringSync(jsonEncode(_memoryStorage), flush: true);
  } catch (_) {}
}

void saveStorageString(String key, String value) {
  _loadIfNeeded();
  _memoryStorage[key] = value;
  _persist();
}

String? getStorageString(String key) {
  _loadIfNeeded();
  return _memoryStorage[key];
}

void removeStorageString(String key) {
  _loadIfNeeded();
  _memoryStorage.remove(key);
  _persist();
}

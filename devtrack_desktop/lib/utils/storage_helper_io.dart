import 'dart:convert';
import 'dart:io';

// Desktop storage: a small JSON file in the user's per-app config directory so the
// session survives restarts (Windows: %APPDATA%\DevTrack, Linux: ~/.config/devtrack,
// macOS: ~/Library/Application Support/DevTrack).
Map<String, String>? _cache;

File? _storageFile() {
  final env = Platform.environment;
  // Never touch the real session file from widget tests
  if (env.containsKey('FLUTTER_TEST')) return null;
  String? dir;
  if (Platform.isWindows) {
    final appData = env['APPDATA'];
    if (appData != null) dir = '$appData${Platform.pathSeparator}DevTrack';
  } else if (Platform.isMacOS) {
    final home = env['HOME'];
    if (home != null) dir = '$home/Library/Application Support/DevTrack';
  } else {
    final xdg = env['XDG_CONFIG_HOME'];
    final home = env['HOME'];
    if (xdg != null && xdg.isNotEmpty) {
      dir = '$xdg/devtrack';
    } else if (home != null) {
      dir = '$home/.config/devtrack';
    }
  }
  if (dir == null) return null;
  return File('$dir${Platform.pathSeparator}session.json');
}

Map<String, String> _load() {
  if (_cache != null) return _cache!;
  try {
    final file = _storageFile();
    if (file != null && file.existsSync()) {
      final data = jsonDecode(file.readAsStringSync());
      if (data is Map) {
        _cache = data.map((k, v) => MapEntry(k.toString(), v.toString()));
        return _cache!;
      }
    }
  } catch (_) {
    // Corrupt or unreadable file: start with an empty session
  }
  _cache = {};
  return _cache!;
}

void _persist() {
  try {
    final file = _storageFile();
    if (file == null) return;
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(jsonEncode(_cache ?? {}));
  } catch (_) {
    // Storage is best effort; the app keeps working with the in-memory copy
  }
}

void saveStorageString(String key, String value) {
  _load()[key] = value;
  _persist();
}

String? getStorageString(String key) {
  return _load()[key];
}

void removeStorageString(String key) {
  _load().remove(key);
  _persist();
}

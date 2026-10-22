final Map<String, String> _memoryStorage = {};

void saveStorageString(String key, String value) {
  _memoryStorage[key] = value;
}

String? getStorageString(String key) {
  return _memoryStorage[key];
}

void removeStorageString(String key) {
  _memoryStorage.remove(key);
}

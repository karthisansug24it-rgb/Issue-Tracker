// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

void saveStorageString(String key, String value) {
  try {
    html.window.localStorage[key] = value;
  } catch (_) {}
}

String? getStorageString(String key) {
  try {
    return html.window.localStorage[key];
  } catch (_) {
    return null;
  }
}

void removeStorageString(String key) {
  try {
    html.window.localStorage.remove(key);
  } catch (_) {}
}

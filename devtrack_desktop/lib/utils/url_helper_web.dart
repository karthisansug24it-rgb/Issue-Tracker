// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

String getBrowserLocation() {
  try {
    final hash = html.window.location.hash;
    if (hash.isNotEmpty) {
      final clean = hash.startsWith('#') ? hash.substring(1) : hash;
      return clean.isEmpty ? '/' : clean;
    }
    final path = html.window.location.pathname ?? '/';
    final search = html.window.location.search ?? '';
    return '$path$search';
  } catch (_) {
    return '/';
  }
}

void setBrowserUrl(String url) {
  try {
    final cleanUrl = url.startsWith('/') ? url : '/$url';
    if (html.window.location.hash != cleanUrl) {
      html.window.location.hash = cleanUrl;
    }
  } catch (_) {}
}

void replaceBrowserUrl(String url) {
  try {
    final cleanUrl = url.startsWith('/') ? url : '/$url';
    if (html.window.location.hash != cleanUrl) {
      html.window.location.hash = cleanUrl;
    }
  } catch (_) {}
}

void listenToUrlChanges(void Function(String) onUrlChanged) {
  try {
    html.window.onHashChange.listen((_) {
      onUrlChanged(getBrowserLocation());
    });
  } catch (_) {}
}

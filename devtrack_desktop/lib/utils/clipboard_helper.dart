import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ClipboardHelper {
  /// Safely copies text to the system clipboard and shows user feedback
  static Future<void> copy(BuildContext context, String text, {String? label}) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(label != null ? 'Copied "$label" to clipboard' : 'Copied to clipboard!'),
              ],
            ),
            backgroundColor: const Color(0xFF1E293B), // Slate 800
            duration: const Duration(milliseconds: 1800),
            behavior: SnackBarBehavior.floating,
            width: 320,
          ),
        );
      }
    } catch (e) {
      debugPrint('Failed to copy text: $e');
    }
  }

  /// Safely reads text from the system clipboard
  static Future<String?> paste() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      return data?.text;
    } catch (e) {
      debugPrint('Failed to read from clipboard: $e');
      return null;
    }
  }

  /// Pastes clipboard text directly into a TextEditingController
  static Future<bool> pasteInto(
    TextEditingController controller, {
    BuildContext? context,
    VoidCallback? onChanged,
  }) async {
    final text = await paste();
    if (text != null && text.isNotEmpty) {
      controller.text = text;
      controller.selection = TextSelection.collapsed(offset: controller.text.length);
      onChanged?.call();
      if (context != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pasted from clipboard!'),
            duration: Duration(milliseconds: 1200),
            behavior: SnackBarBehavior.floating,
            width: 240,
          ),
        );
      }
      return true;
    }
    return false;
  }

  /// Builds a smart suffix icon: Paste button when empty, Clear button when filled
  static Widget buildPasteOrClearSuffix({
    required TextEditingController controller,
    required StateSetter setState,
    BuildContext? context,
    VoidCallback? onChanged,
  }) {
    if (controller.text.isNotEmpty) {
      return IconButton(
        icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
        tooltip: 'Clear',
        onPressed: () {
          setState(() {
            controller.clear();
            onChanged?.call();
          });
        },
      );
    }
    return IconButton(
      icon: const Icon(Icons.content_paste_outlined, size: 18, color: Color(0xFF1E40AF)),
      tooltip: 'Paste from clipboard',
      onPressed: () async {
        final success = await pasteInto(controller, context: context, onChanged: onChanged);
        if (success) {
          setState(() {});
        }
      },
    );
  }
}

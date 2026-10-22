import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/auth_state.dart';
import 'screens/main_layout.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    try {
      // Disables browser's default canvas context menu so Flutter's native
      // Copy, Paste, Cut, Select All toolbars and right-click actions work seamlessly
      await BrowserContextMenu.disableContextMenu();
    } catch (_) {}
  }
  runApp(const DevTrackApp());
}

class DevTrackApp extends StatefulWidget {
  const DevTrackApp({super.key});

  @override
  State<DevTrackApp> createState() => _DevTrackAppState();
}

class _DevTrackAppState extends State<DevTrackApp> {
  @override
  void initState() {
    super.initState();
    AuthState.instance.addListener(_handleAuthChange);
  }

  @override
  void dispose() {
    AuthState.instance.removeListener(_handleAuthChange);
    super.dispose();
  }

  void _handleAuthChange() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DevTrack - Issue & Project Tracking Desktop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E40AF),
          primary: const Color(0xFF1E40AF),
          surface: const Color(0xFFF8FAFC),
        ),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 1,
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Color(0xFF1E40AF),
          selectionColor: Color(0xFFBFDBFE),
          selectionHandleColor: Color(0xFF1E40AF),
        ),
      ),
      home: AuthState.instance.isInitializing
          ? const Scaffold(
              backgroundColor: Color(0xFFF8FAFC),
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF1E40AF)),
              ),
            )
          : (AuthState.instance.isLoggedIn
              ? const MainLayout()
              : const LoginScreen()),
    );
  }
}

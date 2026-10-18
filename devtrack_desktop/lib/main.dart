import 'package:flutter/material.dart';
import 'services/auth_state.dart';
import 'screens/main_layout.dart';
import 'screens/login_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
      ),
      home: AuthState.instance.isLoggedIn
          ? const MainLayout()
          : const LoginScreen(),
    );
  }
}

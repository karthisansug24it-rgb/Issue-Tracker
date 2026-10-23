import 'package:flutter/material.dart';
import '../services/auth_state.dart';
import '../services/api_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isRegisterMode = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _successMessage;

  // Sign In / Common Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Registration Controllers
  final _nameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _selectedDepartment = 'Engineering';
  final _jobTitleController = TextEditingController(text: 'Software Engineer');

  // Fallback list; replaced by the server's departments when reachable
  List<String> _departments = [
    'Engineering',
    'Quality Assurance',
    'Operations & Support',
    'Product Management',
    'Design',
    'Security',
  ];

  @override
  void initState() {
    super.initState();
    // e.g. "Your session has expired..." after an automatic sign-out
    _errorMessage = AuthState.instance.takeSessionMessage();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    try {
      final depts = await ApiService.instance.getDepartments();
      final names = depts.where((d) => d.active).map((d) => d.name).toList();
      if (names.isEmpty || !mounted) return;
      setState(() {
        _departments = names;
        if (!names.contains(_selectedDepartment)) _selectedDepartment = names.first;
      });
    } catch (_) {
      // Keep the built-in list if the server is not reachable yet
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _confirmPasswordController.dispose();
    _jobTitleController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter both email and password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await AuthState.instance.login(email, password);
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleRegister() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final jobTitle = _jobTitleController.text.trim();

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter your full name');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _errorMessage = 'Please enter a valid email address');
      return;
    }
    if (password.length < 8) {
      setState(() => _errorMessage = 'Password must be at least 8 characters');
      return;
    }
    if (password != confirmPassword) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await AuthState.instance.register(
        fullName: name,
        email: email,
        password: password,
        department: _selectedDepartment,
        jobTitle: jobTitle,
      );

      if (mounted) {
        // Auto log in if possible, or switch to sign-in with success banner
        try {
          await AuthState.instance.login(email, password);
        } catch (_) {
          setState(() {
            _isLoading = false;
            _isRegisterMode = false;
            _passwordController.clear();
            _confirmPasswordController.clear();
            _successMessage = 'Account created successfully with basic Employee role! Please sign in.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception:', '').trim();
          _isLoading = false;
        });
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 460;
        final horizontalPadding = isCompact ? 12.0 : 24.0;
        final cardHorizontalPadding = isCompact ? 18.0 : 32.0;
        final cardVerticalPadding = isCompact ? 24.0 : 36.0;

        return Scaffold(
          backgroundColor: const Color(0xFFF1F5F9), // Slate 100
          body: SelectionArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: _isRegisterMode ? 520 : 480),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: cardHorizontalPadding,
                            vertical: cardVerticalPadding,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Brand Header
                              if (!_isRegisterMode) ...[
                                Center(
                                  child: Image.asset(
                                    'assets/images/logo_icon.png',
                                    height: 56,
                                    width: 56,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E40AF),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.track_changes, color: Colors.white, size: 32),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Center(
                                  child: Text(
                                    'Dtrack',
                                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Center(
                                  child: Text(
                                    'Sign in to access projects, tasks, issues, and teams',
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ] else ...[
                                Center(
                                  child: Image.asset(
                                    'assets/images/logo_icon.png',
                                    height: 64,
                                    width: 64,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) => Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E40AF),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 32),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                const Center(
                                  child: Text(
                                    'Account Creation',
                                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Center(
                                  child: Text(
                                    'Register new user account (starts with Employee role)',
                                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),

                              // Success Message Banner
                              if (_successMessage != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.green.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _successMessage!,
                                          style: TextStyle(color: Colors.green.shade900, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Error Message Banner
                              if (_errorMessage != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.red.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Registration Specific Fields
                              if (_isRegisterMode) ...[
                                const Text('Full Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.person_outline, size: 20),
                                    hintText: 'e.g. John Doe',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    isDense: true,
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Email Field
                              const Text('Email Address', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _emailController,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.email_outlined, size: 20),
                                  hintText: 'name@company.com',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.emailAddress,
                                onSubmitted: (_) => _isRegisterMode ? _handleRegister() : _handleLogin(),
                              ),
                              const SizedBox(height: 16),

                              if (_isRegisterMode) ...[
                                if (isCompact) ...[
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Department', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      const SizedBox(height: 6),
                                      DropdownButtonFormField<String>(
                                        initialValue: _selectedDepartment,
                                        isExpanded: true,
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                          isDense: true,
                                        ),
                                        items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13)))).toList(),
                                        onChanged: (val) {
                                          if (val != null) setState(() => _selectedDepartment = val);
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      const Text('Job Title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: _jobTitleController,
                                        decoration: InputDecoration(
                                          hintText: 'Developer',
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          isDense: true,
                                        ),
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Department', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            const SizedBox(height: 6),
                                            DropdownButtonFormField<String>(
                                              initialValue: _selectedDepartment,
                                              isExpanded: true,
                                              decoration: InputDecoration(
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                                isDense: true,
                                              ),
                                              items: _departments.map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13)))).toList(),
                                              onChanged: (val) {
                                                if (val != null) setState(() => _selectedDepartment = val);
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('Job Title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            const SizedBox(height: 6),
                                            TextField(
                                              controller: _jobTitleController,
                                              decoration: InputDecoration(
                                                hintText: 'Developer',
                                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                                isDense: true,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 16),
                              ],

                              // Password Field
                              const Text('Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  prefixIcon: const Icon(Icons.lock_outline, size: 20),
                                  hintText: '••••••••',
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                      size: 18,
                                      color: Colors.grey,
                                    ),
                                    tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                  ),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  isDense: true,
                                ),
                                onSubmitted: (_) => _isRegisterMode ? _handleRegister() : _handleLogin(),
                              ),
                              const SizedBox(height: 16),

                              if (_isRegisterMode) ...[
                                const Text('Confirm Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _confirmPasswordController,
                                  obscureText: true,
                                  decoration: InputDecoration(
                                    prefixIcon: const Icon(Icons.lock_reset, size: 20),
                                    hintText: '••••••••',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    isDense: true,
                                  ),
                                  onSubmitted: (_) => _handleRegister(),
                                ),
                                const SizedBox(height: 16),

                                // Hierarchy Notice Box
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: Colors.blue.shade200),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(Icons.shield_outlined, color: Colors.blue.shade800, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Role Assignment: New accounts automatically receive the basic "Employee" role. Higher administrative privileges (Manager, Admin, Super Admin) can be upgraded by your system administrator.',
                                          style: TextStyle(color: Colors.blue.shade900, fontSize: 11, height: 1.3),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                              ],

                              // Submit Button
                              ElevatedButton(
                                onPressed: _isLoading ? null : (_isRegisterMode ? _handleRegister : _handleLogin),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E40AF),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : Text(
                                        _isRegisterMode ? 'Create Account' : 'Sign In',
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                              ),
                              const SizedBox(height: 20),

                              // Toggle Button: Sign In <-> Account Creation
                              const Divider(),
                              const SizedBox(height: 8),
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    _isRegisterMode ? 'Already have an account?' : 'Need a new account?',
                                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                                  ),
                                  const SizedBox(width: 4),
                                  TextButton.icon(
                                    icon: Icon(_isRegisterMode ? Icons.login : Icons.person_add_alt_1, size: 16),
                                    label: Text(
                                      _isRegisterMode ? 'Back to Sign In' : 'Account Creation',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isRegisterMode = !_isRegisterMode;
                                        _errorMessage = null;
                                        _successMessage = null;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

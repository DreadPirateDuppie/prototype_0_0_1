import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../widgets/cyber/cyber_scaffold.dart';
import '../widgets/cyber/cyber_button.dart';
import '../widgets/cyber/cyber_text_field.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _ageController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _ageController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _signUp() async {
    setState(() => _errorMessage = null);

    // Validate all fields
    if (_emailController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Email address required');
      return;
    }
    
    if (_usernameController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Username required');
      return;
    }

    if (_ageController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Age required');
      return;
    }
    
    final age = int.tryParse(_ageController.text.trim());
    if (age == null || age < 13) {
      setState(() => _errorMessage = 'Minimum age requirement: 13+');
      return;
    }
    
    if (_passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'Password required');
      return;
    }
    
    if (_confirmPasswordController.text.isEmpty) {
      setState(() => _errorMessage = 'Confirm password required');
      return;
    }
    
    if (_passwordController.text.length < 6) {
      setState(() => _errorMessage = 'Password too short (min 6)');
      return;
    }
    
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await SupabaseService.signUp(
        _emailController.text.trim(),
        _passwordController.text,
        username: _usernameController.text.trim(),
        displayName: _usernameController.text.trim(),
        age: age,
      );
      if (mounted) {
        // Show success and go back
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Protocol Initialized. Please Authenticate.'),
            backgroundColor: Color(0xFF00FF41),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CyberScaffold(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_ios, color: Color(0xFF00FF41)),
                  ),
                  const Text(
                    "// NEW USER REGISTRATION",
                    style: TextStyle(
                      color: Color(0xFF00FF41),
                      fontFamily: 'monospace',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              CyberTextField(
                controller: _emailController,
                label: 'Email Address',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: CyberTextField(
                      controller: _usernameController,
                      label: 'Username',
                      prefixIcon: Icons.person_outline,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: CyberTextField(
                      controller: _ageController,
                      label: 'Age',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              CyberTextField(
                controller: _passwordController,
                label: 'Password',
                prefixIcon: Icons.lock_outline,
                obscureText: true,
              ),
              const SizedBox(height: 16),
              
              CyberTextField(
                controller: _confirmPasswordController,
                label: 'Confirm Password',
                prefixIcon: Icons.lock_clock_outlined,
                obscureText: true,
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.red.withOpacity(0.5)), // Fixed: withOpacity
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.red.withOpacity(0.1), // Fixed: withOpacity
                  ),
                  child: Text(
                    "ERROR: $_errorMessage",
                    style: const TextStyle(
                      color: Colors.red,
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              
              CyberButton(
                text: "Initialize Account",
                onPressed: _signUp,
                isLoading: _isLoading,
                isPrimary: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

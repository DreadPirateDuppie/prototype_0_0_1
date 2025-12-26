import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../utils/error_helper.dart';

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
    // Validate all fields
    if (_emailController.text.trim().isEmpty) {
      ErrorHelper.showError(context, 'Please enter an email');
      return;
    }
    
    if (_usernameController.text.trim().isEmpty) {
      ErrorHelper.showError(context, 'Please enter a username');
      return;
    }

    if (_ageController.text.trim().isEmpty) {
      ErrorHelper.showError(context, 'Please enter your age');
      return;
    }
    
    final age = int.tryParse(_ageController.text.trim());
    if (age == null || age < 13) {
      ErrorHelper.showError(context, 'You must be at least 13 years old');
      return;
    }
    
    if (_passwordController.text.isEmpty) {
      ErrorHelper.showError(context, 'Please enter a password');
      return;
    }
    
    if (_confirmPasswordController.text.isEmpty) {
      ErrorHelper.showError(context, 'Please confirm your password');
      return;
    }
    
    // Check password length
    if (_passwordController.text.length < 6) {
      ErrorHelper.showError(context, 'Password must be at least 6 characters');
      return;
    }
    
    // Check if passwords match
    if (_passwordController.text != _confirmPasswordController.text) {
      ErrorHelper.showError(context, 'Passwords do not match');
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
        displayName: _usernameController.text.trim(), // Use username as display name initially
        age: age,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign up successful! Please sign in.')),
        );
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        ErrorHelper.showError(context, error.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ageController,
              decoration: const InputDecoration(
                labelText: 'Age',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(
                labelText: 'Confirm Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _signUp,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Sign Up'),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

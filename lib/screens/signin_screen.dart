import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../widgets/cyber/cyber_scaffold.dart';
import '../widgets/cyber/cyber_button.dart';
import '../widgets/cyber/cyber_text_field.dart';
import 'signup_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Credentials Required';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await SupabaseService.signIn(
        _emailController.text,
        _passwordController.text,
      );
      // Success - AuthWrapper will handle navigation
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = error.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await SupabaseService.signInWithGoogle();
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
            children: [
              // Logo with Halo
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(seconds: 1),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Opacity(
                      opacity: value,
                        child: Image.asset(
                          'assets/images/pushinn_logo_login.png',
                          width: 250, // Slightly larger since border is gone
                          height: 250,
                          fit: BoxFit.contain,
                        ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 40),
              
              // Animated Form
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 50.0, end: 0.0), // Slide up effect
                duration: const Duration(milliseconds: 800),
                curve: Curves.easeOutQuint,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, value),
                    child: Opacity(
                      opacity: (1 - (value / 50)).clamp(0, 1),
                      child: child,
                    ),
                  );
                },
                child: Column(
                  children: [
                     CyberTextField(
                      controller: _emailController,
                      label: 'Identity / Email',
                      prefixIcon: Icons.fingerprint,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),
                    CyberTextField(
                      controller: _passwordController,
                      label: 'Passkey',
                      prefixIcon: Icons.lock_outline,
                      obscureText: true,
                    ),
                    
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 20),
                      Text(
                        _errorMessage!.toUpperCase(),
                        style: const TextStyle(
                          color: Color(0xFFFF4444),
                          fontFamily: 'monospace',
                          fontSize: 12,
                          letterSpacing: 1,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    const SizedBox(height: 40),

                    CyberButton(
                      text: "Authenticate",
                      onPressed: _signIn,
                      isLoading: _isLoading && _errorMessage == null,
                      isPrimary: true,
                    ),

                    const SizedBox(height: 16),

                    CyberButton(
                      text: "Sign In With Google",
                      onPressed: _signInWithGoogle,
                      isPrimary: false,
                      icon: Icons.account_circle,
                    ),

                    const SizedBox(height: 32),

                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const SignUpScreen()),
                        );
                      },
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                          children: [
                            const TextSpan(text: "NO ID FOUND? "),
                            TextSpan(
                              text: "// INITIALIZE NEW USER",
                              style: const TextStyle(
                                color: Color(0xFF00FF41),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

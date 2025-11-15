import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/signin_screen.dart';
import 'screens/home_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/error_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Initialize Supabase with environment variables
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
  );
  
  // Verify environment variables are loaded
  if (dotenv.env['SUPABASE_URL'] == null || dotenv.env['SUPABASE_ANON_KEY'] == null) {
    throw Exception('Missing required environment variables. Please check your .env file.');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ErrorProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'Supabase Auth App',
          theme: themeProvider.getLightTheme(),
          darkTheme: themeProvider.getDarkTheme(),
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          home: const AuthWrapper(),
          builder: (context, child) {
            return Stack(
              children: [
                child!,
                Consumer<ErrorProvider>(
                  builder: (context, errorProvider, child) {
                    if (!errorProvider.isVisible) return const SizedBox.shrink();
                    return Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        color: Colors.red,
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.white),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                errorProvider.errorMessage ?? '',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            IconButton(
                              onPressed: errorProvider.hideError,
                              icon: const Icon(Icons.close, color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// AuthWrapper handles routing based on user authentication state
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        // Check connection state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Check if user is authenticated
        final session = snapshot.data?.session;

        if (session != null) {
          // User is signed in
          return const HomeScreen();
        } else {
          // User is not signed in
          return const SignInScreen();
        }
      },
    );
  }
}

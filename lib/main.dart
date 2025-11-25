import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'screens/signin_screen.dart';
import 'screens/home_screen.dart';
import 'providers/theme_provider.dart';
import 'services/error_service.dart';
import 'services/connectivity_service.dart';
import 'services/rewarded_ad_service.dart';
import 'config/service_locator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables (optional - will use system env vars if file not found)
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Warning: .env file not found, using system environment variables');
  }

  // Initialize Mobile Ads
  await MobileAds.instance.initialize();

  // Get Supabase configuration from dotenv or environment variables
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ??
                      const String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://vgcdednbyjdkyjysvctm.supabase.co');
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? 
                          const String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZnY2RlZG5ieWpka3lqeXN2Y3RtIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMxMzI3NDUsImV4cCI6MjA3ODcwODc0NX0.A9y5TFwhUMKrpiYpQJr_VYfVyyHRH5lpiHLG30Yv4s8');

  // Initialize Supabase with your project URL and anon key
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // Set up service locator for dependency injection
  setupServiceLocator();

  // Initialize error tracking
  ErrorService.initialize();

  // Initialize connectivity monitoring
  await ConnectivityService.initialize();

  // Initialize rewarded ad service
  await RewardedAdService.instance.initialize();

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
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

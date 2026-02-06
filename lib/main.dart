import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'screens/signin_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_setup_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/user_provider.dart';
import 'providers/battle_provider.dart';
import 'providers/post_provider.dart';
import 'providers/navigation_provider.dart';
import 'services/error_service.dart';
import 'services/connectivity_service.dart';
import 'services/rewarded_ad_service.dart';
import 'providers/rewards_provider.dart';
import 'providers/map_provider.dart';
import 'providers/battle_detail_provider.dart';
import 'config/service_locator.dart';
import 'widgets/cyber/cyber_scaffold.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint('Warning: .env file not found, using system environment variables');
  }

  await MobileAds.instance.initialize();

  final supabaseUrl = dotenv.env['SUPABASE_URL'] ??
                      const String.fromEnvironment('SUPABASE_URL');
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? 
                          const String.fromEnvironment('SUPABASE_ANON_KEY');

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    debugPrint('ERROR: Supabase URL or Anon Key is missing.');
  }

  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  setupServiceLocator();
  ErrorService.initialize();
  await ConnectivityService.initialize();
  await RewardedAdService.instance.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => BattleProvider()),
        ChangeNotifierProvider(create: (_) => PostProvider()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => RewardsProvider()),
        ChangeNotifierProvider.value(value: RewardedAdService.instance),
        ChangeNotifierProvider(create: (_) => MapProvider()),
        ChangeNotifierProvider(create: (_) => BattleDetailProvider()),
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
          title: 'Pushinn',
          theme: themeProvider.getLightTheme(),
          darkTheme: themeProvider.getDarkTheme(),
          themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
          debugShowCheckedModeBanner: false,
          // Fixed: Removed global Stack/MatrixRainBackground to avoid overdraw and white screen issues.
          // The CyberScaffold handles background rendering for auth screens.
          home: const AuthWrapper(),
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('AuthWrapper Error: ${snapshot.error}');
          return const Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Text(
                'SYSTEM ERROR: RETRYING',
                style: TextStyle(color: Color(0xFFFF4444), fontFamily: 'monospace'),
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          // Explicit waiting state
          return const _CyberLoadingScreen();
        }

        final session = snapshot.data?.session;

        if (session != null) {
          return const SessionInitializer();
        } else {
          return const SignInScreen();
        }
      },
    );
  }
}

class SessionInitializer extends StatefulWidget {
  const SessionInitializer({super.key});

  @override
  State<SessionInitializer> createState() => _SessionInitializerState();
}

class _SessionInitializerState extends State<SessionInitializer> {
  @override
  void initState() {
    super.initState();
    // Initialize user data when session is found
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        // Safely access provider
        if (context.mounted) {
          context.read<UserProvider>().setUser(user);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserProvider>(
      builder: (context, userProvider, _) {
        // While user data fetches (e.g. username check), show loading
        if (userProvider.isLoading) {
          return const _CyberLoadingScreen();
        }

        if (userProvider.hasCompletedOnboarding) {
          return const HomeScreen();
        } else {
          return const OnboardingScreen();
        }
      },
    );
  }
}

class _CyberLoadingScreen extends StatelessWidget {
  const _CyberLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return CyberScaffold(
      showGrid: false,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
              Image.asset(
                'assets/images/pushinn_logo_login.png',
                width: 350,
                height: 350,
                key: const ValueKey('loading_logo'),
              ),
            const SizedBox(height: 32),
            const SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF00FF41),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "ESTABLISHING UPLINK...",
              style: TextStyle(
                color: Color(0xFF00FF41),
                fontFamily: 'monospace',
                fontSize: 12,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

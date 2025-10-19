import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/annoyance_provider.dart';
import 'providers/preferences_provider.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/email_auth_screen.dart';
import 'utils/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock app to portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Validate required environment variables
  final requiredKeys = Platform.isAndroid 
      ? ['REVENUECAT_ANDROID_KEY']
      : Platform.isIOS 
          ? ['REVENUECAT_IOS_KEY']
          : <String>[];

  for (final key in requiredKeys) {
    if (dotenv.env[key] == null || dotenv.env[key]!.isEmpty) {
      throw Exception('Missing required environment variable: $key. Please check your .env file.');
    }
  }

  // Initialize RevenueCat
  await initPlatformState();

  runApp(const AnnoyedApp());
}

Future<void> initPlatformState() async {
  await Purchases.setLogLevel(LogLevel.debug);

  PurchasesConfiguration configuration;
  if (Platform.isAndroid) {
    configuration = PurchasesConfiguration(dotenv.env['REVENUECAT_ANDROID_KEY'] ?? '');
  } else if (Platform.isIOS) {
    configuration = PurchasesConfiguration(dotenv.env['REVENUECAT_IOS_KEY'] ?? '');
  } else {
    return; // Unsupported platform
  }

  await Purchases.configure(configuration);
}

class AnnoyedApp extends StatelessWidget {
  const AnnoyedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => AnnoyanceProvider()),
        ChangeNotifierProvider(create: (_) => PreferencesProvider()),
      ],
      child: MaterialApp(
        title: 'Annoyed',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primaryTeal,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF0FDFA), // Very light teal
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.black87,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryTeal,
              foregroundColor: Colors.white,
            ),
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: AppColors.primaryTeal,
            foregroundColor: Colors.white,
          ),
        ),
        home: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  bool _isCheckingOnboarding = true;
  bool _hasCompletedOnboarding = false;
  bool _hasEverSignedInWithEmail = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkOnboarding();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check onboarding when app resumes
      _checkOnboarding();
    }
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool('onboarding_completed') ?? false;
    final hasSignedIn = await AuthProvider.hasEverSignedInWithEmail();
    
    if (mounted) {
      setState(() {
        _hasCompletedOnboarding = completed;
        _hasEverSignedInWithEmail = hasSignedIn;
        _isCheckingOnboarding = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    if (_isCheckingOnboarding || authProvider.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // If user is authenticated, show home screen
    if (authProvider.isAuthenticated) {
      return const HomeScreen();
    }

    // If user has signed in with email before but is currently signed out,
    // show sign-in page instead of onboarding
    if (_hasEverSignedInWithEmail) {
      return const EmailAuthScreen(
        initialMode: AuthMode.signIn,
      );
    }

    // New user - show onboarding if not completed
    if (!_hasCompletedOnboarding) {
      return OnboardingScreen(
        onComplete: () {
          // Re-check onboarding status when completed
          _checkOnboarding();
        },
      );
    }

    return const HomeScreen();
  }
}

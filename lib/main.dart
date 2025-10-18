import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/annoyance_provider.dart';
import 'providers/suggestion_provider.dart';
import 'providers/preferences_provider.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
        ChangeNotifierProvider(create: (_) => SuggestionProvider()),
        ChangeNotifierProvider(create: (_) => PreferencesProvider()),
      ],
      child: MaterialApp(
        title: 'Annoyed',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2D9CDB),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF8F9FA),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.black87,
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
    
    if (mounted) {
      setState(() {
        _hasCompletedOnboarding = completed;
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

    // Show onboarding if not authenticated OR if onboarding not completed
    if (!authProvider.isAuthenticated || !_hasCompletedOnboarding) {
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

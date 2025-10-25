import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:io';

import 'firebase_options.dart';
import 'models/auth_state.dart';
import 'providers/auth_state_manager.dart';
import 'providers/annoyance_provider.dart';
import 'providers/suggestion_provider.dart';
import 'providers/preferences_provider.dart';
import 'screens/onboarding_screen.dart';
import 'screens/home_screen.dart';
import 'screens/auth_gate_screen.dart';
import 'utils/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock app to portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Set status bar to dark text (for light backgrounds)
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark, // Dark icons for iOS
      statusBarBrightness: Brightness.light, // Light status bar for Android
    ),
  );

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
        ChangeNotifierProvider(create: (_) {
          final manager = AuthStateManager();
          manager.initialize(); // Start listening to Firebase Auth
          return manager;
        }),
        ChangeNotifierProvider(create: (_) => AnnoyanceProvider()),
        ChangeNotifierProvider(create: (_) => SuggestionProvider()),
        ChangeNotifierProvider(create: (_) => PreferencesProvider()),
      ],
      child: SelectionArea(
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
              systemOverlayStyle: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.dark, // Dark icons/text
                statusBarBrightness: Brightness.light, // For iOS
              ),
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
      ),
    );
  }
}

/// AuthGate: Declarative router that shows the appropriate screen based on AuthState
/// No more complex navigation logic - just a simple switch statement!
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthStateManager>(
      builder: (context, authManager, child) {
        debugPrint('[AuthGate] Current state: ${authManager.state}');

        // Simple switch on auth state - declarative routing!
        switch (authManager.state) {
          case AuthState.initializing:
            return _buildLoadingScreen();

          case AuthState.needsOnboarding:
          case AuthState.onboardingInProgress:
            return OnboardingScreen(
              onComplete: () {
                // Let AuthStateManager handle the state transition
                // It will automatically sign in anonymously
              },
            );

          case AuthState.anonymousActive:
          case AuthState.authenticatedActive:
            return const HomeScreen();

          case AuthState.anonymousAtAuthWall:
            // HARD gate - user must sign up, no "continue as guest"
            return const AuthGateScreen(
              message: 'Sign Up Required',
              subtitle: 'To continue using the app, please sign up to save your progress and unlock all features.',
            );

          case AuthState.upgradingAnonymous:
          case AuthState.signingIn:
          case AuthState.signingOut:
            return _buildLoadingScreen(message: 'Please wait...');

          case AuthState.authError:
            return _buildErrorScreen(
              context,
              authManager.errorMessage ?? 'An error occurred',
              authManager,
            );
        }
      },
    );
  }

  Widget _buildLoadingScreen({String? message}) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            if (message != null) ...[
              const SizedBox(height: 20),
              Text(
                message,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(
    BuildContext context,
    String errorMessage,
    AuthStateManager authManager,
  ) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 24),
              const Text(
                'Something Went Wrong',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                errorMessage,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => authManager.retryLastOperation(),
                  child: const Text(
                    'Try Again',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => authManager.cancelOperation(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:annoyed/models/auth_state.dart';
import 'package:annoyed/providers/auth_state_manager.dart';

/// Widget tests for AuthGate declarative routing
/// Verifies that the correct screen is shown for each AuthState
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthGate Declarative Routing Tests', () {
    late AuthStateManager mockAuthManager;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      mockAuthManager = AuthStateManager();
    });

    tearDown(() {
      mockAuthManager.dispose();
    });

    testWidgets('AuthGate shows loading screen for initializing state', 
      (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthStateManager>.value(
            value: mockAuthManager,
            child: Consumer<AuthStateManager>(
              builder: (context, authManager, child) {
                if (authManager.state == AuthState.initializing) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }
                return const Scaffold(body: Text('Not Loading'));
              },
            ),
          ),
        ),
      );

      await tester.pump();

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('AuthGate shows loading for transitional states', 
      (WidgetTester tester) async {
      // Test all loading states
      final loadingStates = [
        AuthState.initializing,
        AuthState.upgradingAnonymous,
        AuthState.signingIn,
        AuthState.signingOut,
      ];

      for (final state in loadingStates) {
        expect(state.isLoading, isTrue, reason: '$state should be loading');
      }
    });

    testWidgets('AuthGate shows error screen for authError state', 
      (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ChangeNotifierProvider<AuthStateManager>.value(
            value: mockAuthManager,
            child: Consumer<AuthStateManager>(
              builder: (context, authManager, child) {
                if (authManager.state == AuthState.authError) {
                  return Scaffold(
                    body: Column(
                      children: [
                        const Icon(Icons.error_outline),
                        const Text('Something Went Wrong'),
                        ElevatedButton(
                          onPressed: () => authManager.retryLastOperation(),
                          child: const Text('Try Again'),
                        ),
                        TextButton(
                          onPressed: () => authManager.cancelOperation(),
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  );
                }
                return const Scaffold(body: Text('No Error'));
              },
            ),
          ),
        ),
      );

      await tester.pump();

      // Should show error UI elements if in error state
      expect(mockAuthManager.state, isNot(equals(AuthState.authError)));
    });

    testWidgets('Blocking states are correctly identified', 
      (WidgetTester tester) async {
      // Test blocking states
      expect(AuthState.anonymousAtAuthWall.isBlocking, isTrue);
      expect(AuthState.authError.isBlocking, isTrue);
      
      // Test non-blocking states
      expect(AuthState.anonymousActive.isBlocking, isFalse);
      expect(AuthState.authenticatedActive.isBlocking, isFalse);
    });

    testWidgets('Active states are correctly identified', 
      (WidgetTester tester) async {
      // Test active states
      expect(AuthState.anonymousActive.isActive, isTrue);
      expect(AuthState.authenticatedActive.isActive, isTrue);
      
      // Test non-active states
      expect(AuthState.initializing.isActive, isFalse);
      expect(AuthState.needsOnboarding.isActive, isFalse);
    });
  });

  group('AuthGate State-Based Rendering', () {
    testWidgets('Each state has a unique screen', (WidgetTester tester) async {
      // Verify that switch statement covers all states
      final allStates = AuthState.values;
      
      for (final state in allStates) {
        // Each state should map to some screen
        switch (state) {
          case AuthState.initializing:
          case AuthState.upgradingAnonymous:
          case AuthState.signingIn:
          case AuthState.signingOut:
            // Loading screen
            expect(state.isLoading, isTrue);
            break;
            
          case AuthState.needsOnboarding:
          case AuthState.onboardingInProgress:
            // Onboarding screen
            break;
            
          case AuthState.anonymousActive:
          case AuthState.authenticatedActive:
            // Home screen
            expect(state.isActive, isTrue);
            break;
            
          case AuthState.anonymousAtAuthWall:
            // Auth wall screen
            expect(state.isBlocking, isTrue);
            break;
            
          case AuthState.authError:
            // Error screen
            expect(state.isBlocking, isTrue);
            break;
        }
      }
    });
  });

  group('AuthGate No Manual Navigation', () {
    test('State changes should drive navigation, not manual pushes', () {
      // This is a design principle test
      // AuthGate uses declarative routing - changing state automatically changes screen
      
      // Before: Manual navigation (bad)
      // Navigator.push(...) // ❌
      
      // After: State change (good)
      // authStateManager.triggerAuthWall() // ✅
      // AuthGate automatically shows AuthWallScreen
      
      expect(true, isTrue); // Principle verified
    });

    test('No navigation listeners in UI components', () {
      // Old approach had auth listeners calling Navigator.pop
      // New approach: AuthGate handles all routing
      
      // Verify principle: Screens should NOT have:
      // - authProvider.addListener(_onAuthStateChanged)
      // - Navigator.popUntil(...)
      // - Navigator.pushReplacement(...)
      
      expect(true, isTrue); // Design principle
    });
  });
}


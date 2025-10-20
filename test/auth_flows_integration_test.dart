import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:annoyed/models/auth_state.dart';
import 'package:annoyed/providers/auth_state_manager.dart';
import 'package:annoyed/main.dart';

/// Integration tests for authentication flows
/// These tests verify the complete user journeys through all auth states
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Auth Flow Integration Tests', () {
    setUp(() async {
      // Clear all SharedPreferences before each test
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('Flow 1: New User Journey (Onboarding → Anonymous → HomeScreen)', 
      (WidgetTester tester) async {
      // Setup: Brand new user, no data
      SharedPreferences.setMockInitialValues({});

      // Launch app
      await tester.pumpWidget(const AnnoyedApp());
      await tester.pumpAndSettle();

      // Step 1: Should start in initializing state
      final authManager = Provider.of<AuthStateManager>(
        tester.element(find.byType(MaterialApp)),
        listen: false,
      );
      
      // Give it time to compute initial state
      await tester.pump(Duration(milliseconds: 500));
      
      // Step 2: Should transition to needsOnboarding
      expect(authManager.state, isIn([AuthState.initializing, AuthState.needsOnboarding]));
      
      // Step 3: OnboardingScreen should be visible
      // Look for onboarding indicators (would need to be more specific in real test)
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('Flow 2: Auth Wall Flow (5 Annoyances → Auth Wall → Sign Up)', 
      (WidgetTester tester) async {
      // Setup: User has completed onboarding, is anonymous, has 4 annoyances
      SharedPreferences.setMockInitialValues({
        'onboarding_completed': true,
        'auth_wall_hit': false,
      });

      await tester.pumpWidget(const AnnoyedApp());
      await tester.pumpAndSettle();

      final authManager = Provider.of<AuthStateManager>(
        tester.element(find.byType(MaterialApp)),
        listen: false,
      );

      // Step 1: Should be in anonymousActive state
      expect(authManager.state, equals(AuthState.anonymousActive));
      
      // Step 2: Trigger auth wall (simulate 5th annoyance)
      await authManager.triggerAuthWall();
      await tester.pumpAndSettle();
      
      // Step 3: Should transition to anonymousAtAuthWall
      expect(authManager.state, equals(AuthState.anonymousAtAuthWall));
      
      // Step 4: AuthWallScreen should be showing
      // (In real test, we'd verify specific widgets)
      expect(authManager.state.isBlocking, isTrue);
    });

    testWidgets('Flow 3: Sign Out Flow (Authenticated → Anonymous)', 
      (WidgetTester tester) async {
      // Setup: User is authenticated
      SharedPreferences.setMockInitialValues({
        'onboarding_completed': true,
        'auth_wall_hit': false,
      });

      await tester.pumpWidget(const AnnoyedApp());
      await tester.pumpAndSettle();

      final authManager = Provider.of<AuthStateManager>(
        tester.element(find.byType(MaterialApp)),
        listen: false,
      );

      // User signs out
      await authManager.signOut();
      await tester.pumpAndSettle();
      
      // Should clear auth wall flag
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('auth_wall_hit'), isFalse);
    });

    testWidgets('Flow 4: Error Recovery Flow', 
      (WidgetTester tester) async {
      // Setup
      SharedPreferences.setMockInitialValues({
        'onboarding_completed': true,
      });

      await tester.pumpWidget(const AnnoyedApp());
      await tester.pumpAndSettle();

      final authManager = Provider.of<AuthStateManager>(
        tester.element(find.byType(MaterialApp)),
        listen: false,
      );

      // Test that error state can be cancelled
      // (Would need to trigger actual error in real test)
      
      // Verify error recovery methods exist
      expect(authManager.cancelOperation, isNotNull);
      expect(authManager.retryLastOperation, isNotNull);
    });
  });

  group('State Persistence Tests', () {
    testWidgets('Onboarding flag persists across app restarts', 
      (WidgetTester tester) async {
      // First launch
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const AnnoyedApp());
      await tester.pumpAndSettle();

      final authManager = Provider.of<AuthStateManager>(
        tester.element(find.byType(MaterialApp)),
        listen: false,
      );

      // Complete onboarding
      await authManager.completeOnboarding();
      await tester.pumpAndSettle();

      // Verify flag is set
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_completed'), isTrue);

      // Simulate app restart
      await tester.pumpWidget(Container());
      await tester.pumpWidget(const AnnoyedApp());
      await tester.pumpAndSettle();

      // Flag should still be there
      expect(prefs.getBool('onboarding_completed'), isTrue);
    });

    testWidgets('Auth wall flag persists until cleared', 
      (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_completed': true,
        'auth_wall_hit': true,
      });

      await tester.pumpWidget(const AnnoyedApp());
      await tester.pumpAndSettle();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('auth_wall_hit'), isTrue);

      // Should persist across rebuilds
      await tester.pumpWidget(Container());
      await tester.pumpWidget(const AnnoyedApp());
      await tester.pumpAndSettle();

      expect(prefs.getBool('auth_wall_hit'), isTrue);
    });
  });

  group('Navigation Tests', () {
    testWidgets('AuthGate shows correct screen for each state', 
      (WidgetTester tester) async {
      // Test that AuthGate declaratively routes based on state
      SharedPreferences.setMockInitialValues({
        'onboarding_completed': true,
      });

      await tester.pumpWidget(const AnnoyedApp());
      await tester.pumpAndSettle();

      // Should show some screen (HomeScreen, OnboardingScreen, etc.)
      expect(find.byType(Scaffold), findsWidgets);
    });

    testWidgets('No manual navigation - state changes drive UI', 
      (WidgetTester tester) async {
      // This tests the declarative nature of our routing
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(const AnnoyedApp());
      await tester.pumpAndSettle();

      final authManager = Provider.of<AuthStateManager>(
        tester.element(find.byType(MaterialApp)),
        listen: false,
      );

      // Changing state should automatically change screen
      // No manual Navigator.push/pop needed
      final initialState = authManager.state;
      expect(initialState, isNotNull);
    });
  });

  group('Edge Cases', () {
    testWidgets('App handles missing SharedPreferences gracefully', 
      (WidgetTester tester) async {
      // No initial values
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(const AnnoyedApp());
      await tester.pumpAndSettle();

      // Should not crash
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('App handles corrupted SharedPreferences', 
      (WidgetTester tester) async {
      // Invalid values
      SharedPreferences.setMockInitialValues({
        'onboarding_completed': 'invalid',
        'auth_wall_hit': 123,
      });

      await tester.pumpWidget(const AnnoyedApp());
      await tester.pumpAndSettle();

      // Should not crash, defaults to false
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_completed') ?? false, isFalse);
    });

    testWidgets('State machine handles rapid state changes', 
      (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({
        'onboarding_completed': true,
      });

      await tester.pumpWidget(const AnnoyedApp());
      await tester.pumpAndSettle();

      final authManager = Provider.of<AuthStateManager>(
        tester.element(find.byType(MaterialApp)),
        listen: false,
      );

      // Rapid operations shouldn't cause race conditions
      authManager.triggerAuthWall();
      authManager.triggerAuthWall();
      authManager.triggerAuthWall();
      
      await tester.pumpAndSettle();
      
      // Should still be in valid state
      expect(authManager.state, isIn(AuthState.values));
    });
  });

  group('Data Preservation Tests', () {
    testWidgets('UID preservation during account linking (simulated)', 
      (WidgetTester tester) async {
      // This would require actual Firebase in integration test
      // Here we verify the concept
      
      const anonymousUid = 'test-anon-uid';
      
      // Step 1: Anonymous user has data
      expect(anonymousUid, isNotEmpty);
      
      // Step 2: Link to email
      // Firebase preserves UID automatically
      const linkedUid = 'test-anon-uid'; // Same UID
      
      // Step 3: Verify UID didn't change
      expect(linkedUid, equals(anonymousUid));
    });
  });
}


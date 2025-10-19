import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/annoyance_provider.dart';
import '../providers/suggestion_provider.dart';
import '../providers/preferences_provider.dart';
import '../services/analytics_service.dart';
import '../services/paywall_service.dart';
import 'suggestion_card_screen.dart';
import 'paywall_screen.dart';

class CoachPromptScreen extends StatelessWidget {
  const CoachPromptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              
              const Icon(
                Icons.lightbulb_outline,
                size: 80,
                color: Color(0xFF0F766E),
              ),
              
              const SizedBox(height: 32),
              
              const Text(
                'Good moment for a suggestion?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const Spacer(),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () async {
                        await AnalyticsService.logCoachNotNow();
                        if (context.mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Okay—try again later.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Not now',
                        style: TextStyle(fontSize: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        await AnalyticsService.logCoachYes();
                        
                        // Generate suggestion
                        if (context.mounted) {
                          final authProvider = Provider.of<AuthProvider>(
                            context,
                            listen: false,
                          );
                          final annoyanceProvider =
                              Provider.of<AnnoyanceProvider>(
                            context,
                            listen: false,
                          );
                          final suggestionProvider =
                              Provider.of<SuggestionProvider>(
                            context,
                            listen: false,
                          );
                          final prefsProvider =
                              Provider.of<PreferencesProvider>(
                            context,
                            listen: false,
                          );

                          final uid = authProvider.userId;
                          if (uid == null) {
                            Navigator.of(context).pop();
                            return;
                          }

                          // Check if should show paywall
                          final isPro = prefsProvider.isPro;
                          final shouldPaywall =
                              await PaywallService.shouldShowPaywall(
                                  uid, isPro);

                          if (shouldPaywall && context.mounted) {
                            Navigator.of(context).pop(); // Close prompt
                            final upgraded = await Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                builder: (context) => const PaywallScreen(),
                              ),
                            );

                            // If user didn't upgrade, don't generate suggestion
                            if (upgraded != true) return;
                          }

                          if (!context.mounted) return;

                          // Get top category and a recent trigger
                          final topCategory =
                              annoyanceProvider.getTopCategory() ??
                                  'Environment';
                          final recentAnnoyance =
                              annoyanceProvider.annoyances.isNotEmpty
                                  ? annoyanceProvider.annoyances.first
                                  : null;

                          if (recentAnnoyance == null) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                    'No recent annoyances to generate suggestion'),
                              ),
                            );
                            return;
                          }

                          // Show loading
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const Center(
                              child: CircularProgressIndicator(),
                            ),
                          );

                          // Generate suggestion
                          final suggestion =
                              await suggestionProvider.generateSuggestion(
                            uid: uid,
                            category: topCategory,
                            trigger: recentAnnoyance.trigger,
                          );

                          if (context.mounted) {
                            Navigator.of(context).pop(); // Close loading
                            
                            // Only pop the prompt if we didn't already pop it for paywall
                            if (!shouldPaywall) {
                              Navigator.of(context).pop(); // Close prompt
                            }

                            if (suggestion != null) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => SuggestionCardScreen(
                                    suggestion: suggestion,
                                  ),
                                ),
                              );
                            }
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Yes',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


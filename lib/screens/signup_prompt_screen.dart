import 'package:flutter/material.dart';
import '../widgets/animated_gradient_container.dart';
import '../utils/app_colors.dart';
import 'email_auth_screen.dart';

/// Screen shown after 5th annoyance to prompt email sign-up
class SignUpPromptScreen extends StatelessWidget {
  final String message;
  final String? subtitle;
  
  const SignUpPromptScreen({
    super.key,
    this.message = 'Unlock Full Features!',
    this.subtitle,
  });

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
              
              // Icon
              ClipOval(
                child: AnimatedGradientContainer(
                  colors: const [
                    AppColors.primaryTealLight,
                    AppColors.primaryTeal,
                    AppColors.accentCoralLight,
                  ],
                  duration: const Duration(seconds: 4),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    child: const Icon(
                      Icons.lock_open,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Message
              Text(
                message,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              Text(
                subtitle ?? 'Sign up to save your progress and unlock coaching insights',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 32),
              
              // Benefits list
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryTealLight.withAlpha(26),
                      AppColors.accentCoralLight.withAlpha(26),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Column(
                  children: [
                    _BenefitRow(
                      icon: Icons.save,
                      text: 'Keep all your recorded annoyances',
                    ),
                    SizedBox(height: 16),
                    _BenefitRow(
                      icon: Icons.lightbulb,
                      text: 'Get AI-powered coaching insights',
                    ),
                    SizedBox(height: 16),
                    _BenefitRow(
                      icon: Icons.card_giftcard,
                      text: 'Access exclusive deals from Coach Craig',
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              // Sign up button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AnimatedGradientContainer(
                    colors: const [
                      AppColors.primaryTealLight,
                      AppColors.primaryTeal,
                      AppColors.primaryTealDark,
                    ],
                    duration: const Duration(seconds: 3),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const EmailAuthScreen(
                              isUpgrade: true,
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Sign Up & Keep My Data',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Sign in button (if they already have account)
              Column(
                children: [
                  const Text(
                    'Already have an account?',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const EmailAuthScreen(
                            initialMode: AuthMode.signIn,
                          ),
                        ),
                      );
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text(
                      'Sign In',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 60), // Extra padding to clear iOS home indicator
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;
  
  const _BenefitRow({
    required this.icon,
    required this.text,
  });
  
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: AppColors.primaryTeal,
          size: 24,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}


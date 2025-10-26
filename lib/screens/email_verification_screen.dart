import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/auth_state_manager.dart';
import '../utils/app_colors.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isResending = false;
  bool _isChecking = false;
  DateTime? _lastResendTime;
  
  final int _resendCooldownSeconds = 60;

  @override
  void initState() {
    super.initState();
    // Automatically check verification status every 3 seconds
    _startAutoCheck();
  }

  void _startAutoCheck() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        await _checkVerificationSilently();
        return true; // Continue checking
      }
      return false; // Stop if widget is disposed
    });
  }

  Future<void> _checkVerificationSilently() async {
    try {
      await FirebaseAuth.instance.currentUser?.reload();
      final user = FirebaseAuth.instance.currentUser;
      
      if (user?.emailVerified == true) {
        // Email verified! Trigger state recompute
        if (mounted) {
          final authManager = Provider.of<AuthStateManager>(context, listen: false);
          authManager.initialize(); // This will recompute state and show home screen
        }
      }
    } catch (e) {
      debugPrint('[EmailVerification] Silent check error: $e');
    }
  }

  Future<void> _checkVerification() async {
    setState(() => _isChecking = true);
    
    try {
      await FirebaseAuth.instance.currentUser?.reload();
      final user = FirebaseAuth.instance.currentUser;
      
      if (user?.emailVerified == true) {
        // Email verified! Trigger state recompute
        if (mounted) {
          final authManager = Provider.of<AuthStateManager>(context, listen: false);
          authManager.initialize();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Email verified successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email not verified yet. Please check your inbox and click the link.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[EmailVerification] Check error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking verification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    
    setState(() => _isChecking = false);
  }

  Future<void> _resendVerification() async {
    // Check cooldown
    if (_lastResendTime != null) {
      final timeSinceLastResend = DateTime.now().difference(_lastResendTime!);
      if (timeSinceLastResend.inSeconds < _resendCooldownSeconds) {
        final remainingSeconds = _resendCooldownSeconds - timeSinceLastResend.inSeconds;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please wait $remainingSeconds seconds before resending'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    setState(() => _isResending = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('No user logged in');
      }
      
      debugPrint('[EmailVerification] Attempting to send verification email to: ${user.email}');
      debugPrint('[EmailVerification] User ID: ${user.uid}');
      debugPrint('[EmailVerification] Email verified status: ${user.emailVerified}');
      
      await user.sendEmailVerification();
      _lastResendTime = DateTime.now();
      
      debugPrint('[EmailVerification] ✓ sendEmailVerification() completed successfully');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Verification email sent! Check your inbox.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('[EmailVerification] ❌ Resend error: $e');
      debugPrint('[EmailVerification] Error type: ${e.runtimeType}');
      if (e is FirebaseAuthException) {
        debugPrint('[EmailVerification] Firebase error code: ${e.code}');
        debugPrint('[EmailVerification] Firebase error message: ${e.message}');
      }
      
      if (mounted) {
        String errorMessage = 'Failed to send email';
        if (e.toString().contains('too-many-requests')) {
          errorMessage = 'Too many attempts. Please try again later.';
        } else if (e is FirebaseAuthException) {
          errorMessage = e.message ?? errorMessage;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
    
    setState(() => _isResending = false);
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out?'),
        content: const Text('Are you sure you want to sign out? You\'ll need to sign up again with a verified email.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authManager = Provider.of<AuthStateManager>(context, listen: false);
      await authManager.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: _signOut,
        ),
        actions: [
          TextButton(
            onPressed: _signOut,
            child: const Text('Sign Out'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Email icon with pulse animation
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.primaryTeal.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.email_outlined,
                  size: 80,
                  color: AppColors.primaryTeal,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Title
              const Text(
                'Verify Your Email',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // Instructions
              Text(
                'We sent a verification link to:',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              // Email address
              Text(
                email,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryTeal,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              // Spam folder warning (bold and prominent)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade300, width: 2),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 28, color: Colors.orange.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'CHECK YOUR SPAM/JUNK FOLDER',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Verification emails often end up in spam',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange.shade800,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Info box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 20, color: Colors.grey.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Click the link in the email to verify your account',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 40),
              
              // I've Verified button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isChecking ? null : _checkVerification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  child: _isChecking
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'I\'ve Verified My Email',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Resend button
              TextButton(
                onPressed: _isResending ? null : _resendVerification,
                child: _isResending
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Resend Verification Email',
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


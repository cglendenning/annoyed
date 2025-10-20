import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../utils/app_colors.dart';
import '../utils/password_validator.dart';
import '../utils/constants.dart';
import '../widgets/animated_gradient_container.dart';
import 'terms_screen.dart';
import 'privacy_policy_screen.dart';

enum AuthMode { signUp, signIn }

class EmailAuthScreen extends StatefulWidget {
  final bool isUpgrade; // true if upgrading from anonymous
  final AuthMode initialMode;
  
  const EmailAuthScreen({
    super.key,
    this.isUpgrade = false,
    this.initialMode = AuthMode.signUp,
  });

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  late bool _isSignUp;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _marketingOptIn = false;
  bool _agreedToTerms = false;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;
  String? _authError; // Inline error message for auth failures
  DateTime? _lastPasswordResetRequest;
  
  @override
  void initState() {
    super.initState();
    _isSignUp = widget.initialMode == AuthMode.signUp;
    
    // Add listeners to update password strength indicator in real-time
    _passwordController.addListener(() {
      // Clear auth error when user starts typing
      if (_authError != null) {
        setState(() {
          _authError = null;
        });
      }
      
      if (_isSignUp) {
        setState(() {});
        // Also validate confirm password if user has started typing
        if (_confirmPasswordController.text.isNotEmpty) {
          _formKey.currentState?.validate();
        }
      }
    });
    _confirmPasswordController.addListener(() {
      if (_isSignUp && _confirmPasswordController.text.isNotEmpty) {
        // Enable auto-validation once user starts typing in confirm password
        setState(() {
          _autovalidateMode = AutovalidateMode.always;
        });
      }
    });
    
    // Clear auth error when user starts typing in email field
    _emailController.addListener(() {
      if (_authError != null) {
        setState(() {
          _authError = null;
        });
      }
    });
  }
  
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
  
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }
    
    // Improved email regex - more robust validation
    final emailRegex = RegExp(
      r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$"
    );
    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }
    
    return null;
  }
  
  Future<void> _submit() async {
    setState(() {
      _autovalidateMode = AutovalidateMode.onUserInteraction;
    });
    
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_isSignUp && !_agreedToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please accept the Terms of Service to continue'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Haptic feedback
    HapticFeedback.mediumImpact();
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      debugPrint('[EmailAuthScreen] Starting authentication...');
      debugPrint('[EmailAuthScreen] Mode: ${_isSignUp ? "Sign Up" : "Sign In"}, IsUpgrade: ${widget.isUpgrade}');
      
      if (_isSignUp) {
        if (widget.isUpgrade) {
          // Link anonymous account to email/password
          debugPrint('[EmailAuthScreen] Calling linkAnonymousToEmail...');
          await authProvider.linkAnonymousToEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            marketingOptIn: _marketingOptIn,
          );
        } else {
          // Regular sign up
          debugPrint('[EmailAuthScreen] Calling signUpWithEmail...');
          await authProvider.signUpWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            marketingOptIn: _marketingOptIn,
          );
        }
      } else {
        debugPrint('[EmailAuthScreen] Calling signInWithEmail...');
        await authProvider.signInWithEmail(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
      
      debugPrint('[EmailAuthScreen] Authentication successful, navigating...');
      
      // Navigation handled by AuthGate - clear stack and let AuthGate route
      if (mounted) {
        try {
          // Pop all screens and return to root, letting AuthGate handle routing
          Navigator.of(context).popUntil((route) => route.isFirst);
        } catch (e) {
          // If popUntil fails, just pop current screen
          debugPrint('[EmailAuthScreen] Navigation error: $e');
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      debugPrint('[EmailAuthScreen] Authentication error caught: $e');
      debugPrint('[EmailAuthScreen] Error type: ${e.runtimeType}');
      
      if (mounted) {
        String errorMessage = AppErrorMessages.invalidCredentials;
        
        // Check for Firebase-specific errors
        final errorString = e.toString().toLowerCase();
        debugPrint('[EmailAuthScreen] Error string (lowercase): $errorString');
        
        // Only show specific errors for sign-up to help users
        if (_isSignUp) {
          if (errorString.contains('email-already-in-use') || errorString.contains('already in use')) {
            errorMessage = AppErrorMessages.emailAlreadyInUse;
            debugPrint('[EmailAuthScreen] Detected email-already-in-use error');
          } else if (errorString.contains('weak-password')) {
            errorMessage = AppErrorMessages.weakPassword;
          } else if (errorString.contains('invalid-email')) {
            errorMessage = 'Please enter a valid email address';
          } else if (errorString.contains('credential-already-in-use')) {
            // Firebase sometimes uses this error for account linking
            errorMessage = 'This email is already registered. Try signing in instead.';
            debugPrint('[EmailAuthScreen] Detected credential-already-in-use error');
          } else {
            // Show the actual error for debugging
            errorMessage = 'Sign up failed: ${e.toString()}';
          }
        }
        // For sign-in, use generic message to prevent account enumeration
        
        debugPrint('[EmailAuthScreen] Setting error message: $errorMessage');
        
        setState(() {
          _authError = errorMessage;
          _isLoading = false;
        });
        
        debugPrint('[EmailAuthScreen] Error state updated, loading: $_isLoading');
      } else {
        debugPrint('[EmailAuthScreen] Widget not mounted, cannot update state');
      }
    }
  }
  
  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    
    if (email.isEmpty) {
      setState(() {
        _authError = 'Please enter your email address';
      });
      return;
    }
    
    // Rate limiting - prevent spam
    if (_lastPasswordResetRequest != null) {
      final timeSinceLastRequest = DateTime.now().difference(_lastPasswordResetRequest!);
      if (timeSinceLastRequest.inSeconds < AppConstants.passwordResetThrottleSeconds) {
        final remainingSeconds = AppConstants.passwordResetThrottleSeconds - timeSinceLastRequest.inSeconds;
        setState(() {
          _authError = 'Please wait $remainingSeconds seconds before requesting another reset';
        });
        return;
      }
    }
    
    setState(() {
      _isLoading = true;
      _authError = null;
    });
    
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.resetPassword(email);
      _lastPasswordResetRequest = DateTime.now();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        // Always show success message (security best practice - don't reveal if email exists)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('If an account exists with this email, a password reset link has been sent.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _authError = 'Unable to process password reset. Please try again.';
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Form(
            key: _formKey,
            autovalidateMode: _autovalidateMode,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 40),
                
                // App icon
                Center(
                  child: ClipOval(
                    child: AnimatedGradientContainer(
                      colors: const [
                        AppColors.primaryTealLight,
                        AppColors.primaryTeal,
                        AppColors.accentCoralLight,
                      ],
                      duration: const Duration(seconds: 4),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        child: const Icon(
                          Icons.bolt_outlined,
                          size: 50,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // App name
                const Text(
                  'Annoyed',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 8),
                
              Text(
                widget.isUpgrade
                    ? 'Keep your progress & unlock features'
                    : (_isSignUp ? 'Create your account' : 'Welcome back'),
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
                
                const SizedBox(height: 40),
                
                // Auth error display
                if (_authError != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.shade200,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.red.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.bolt_outlined,
                            color: Colors.red,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _authError!,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                
                // Email field
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'your@email.com',
                    prefixIcon: const Icon(Icons.email_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: _validateEmail,
                  enabled: !_isLoading,
                ),
                
                const SizedBox(height: 16),
                
                // Password field
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    
                    if (_isSignUp) {
                      return PasswordValidator.validate(value);
                    }
                    
                    return null;
                  },
                  enabled: !_isLoading,
                ),
                
                // Password strength indicator (sign up only)
                if (_isSignUp && _passwordController.text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPasswordStrength(),
                        const SizedBox(height: 8),
                        _buildPasswordRequirements(),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // Confirm password (sign up only)
                if (_isSignUp)
                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      prefixIcon: const Icon(Icons.lock_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureConfirmPassword = !_obscureConfirmPassword;
                          });
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value != _passwordController.text) {
                        return 'Passwords do not match';
                      }
                      return null;
                    },
                    enabled: !_isLoading,
                  ),
                
                if (_isSignUp) const SizedBox(height: 24),
                
                // Terms acceptance (sign up only)
                if (_isSignUp)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTealLight.withAlpha(26),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _agreedToTerms,
                          onChanged: _isLoading
                              ? null
                              : (value) {
                                  setState(() {
                                    _agreedToTerms = value ?? false;
                                  });
                                },
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: RichText(
                              text: TextSpan(
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black87,
                                ),
                                children: [
                                  const TextSpan(
                                    text: 'I accept the ',
                                  ),
                                  TextSpan(
                                    text: 'Terms of Service',
                                    style: const TextStyle(
                                      color: AppColors.primaryTeal,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => Dialog.fullscreen(
                                            child: const TermsScreen(),
                                          ),
                                        );
                                      },
                                  ),
                                  const TextSpan(text: ' and '),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: const TextStyle(
                                      color: AppColors.primaryTeal,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () {
                                        showDialog(
                                          context: context,
                                          builder: (context) => Dialog.fullscreen(
                                            child: const PrivacyPolicyScreen(),
                                          ),
                                        );
                                      },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                if (_isSignUp) const SizedBox(height: 16),
                
                // Marketing opt-in (sign up only)
                if (_isSignUp)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.accentCoralLight.withAlpha(51),
                          AppColors.primaryTealLight.withAlpha(51),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.accentCoralLight,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: _marketingOptIn,
                          onChanged: _isLoading
                              ? null
                              : (value) {
                                  setState(() {
                                    _marketingOptIn = value ?? false;
                                  });
                                },
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      '🎁 ',
                                      style: TextStyle(fontSize: 18),
                                    ),
                                    const Text(
                                      'Get Exclusive Perks!',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.accentCoral,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Receive weekly coaching tips, exclusive deals, '
                                  'and early access to new features from Coach Craig himself! '
                                  '(You can unsubscribe anytime)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 24),
                
                // Submit button
                SizedBox(
                  height: 56,
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedGradientContainer(
                            colors: const [
                              AppColors.primaryTealLight,
                              AppColors.primaryTeal,
                              AppColors.primaryTealDark,
                            ],
                            duration: const Duration(seconds: 3),
                            child: ElevatedButton(
                              onPressed: _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                _isSignUp ? 'Create Account' : 'Sign In',
                                style: const TextStyle(
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
                
                // Forgot password (sign in only)
                if (!_isSignUp)
                  Center(
                    child: TextButton(
                      onPressed: _isLoading ? null : _forgotPassword,
                      child: const Text('Forgot Password?'),
                    ),
                  ),
                
                const SizedBox(height: 16),
                
                // Toggle sign up / sign in
                Center(
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _isSignUp = !_isSignUp;
                              _agreedToTerms = false;
                              _marketingOptIn = false;
                              _autovalidateMode = AutovalidateMode.disabled;
                              _authError = null; // Clear any previous auth errors
                            });
                          },
                    child: Text(
                      _isSignUp
                          ? 'Already have an account? Sign In'
                          : 'Don\'t have an account? Sign Up',
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildPasswordStrength() {
    final strength = PasswordValidator.getStrength(_passwordController.text);
    final label = PasswordValidator.getStrengthLabel(strength);
    
    Color color;
    if (strength <= 1) {
      color = Colors.red;
    } else if (strength == 2) {
      color = Colors.orange;
    } else if (strength == 3) {
      color = Colors.yellow.shade700;
    } else {
      color = Colors.green;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(4, (index) {
            return Expanded(
              child: Container(
                height: 4,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: index < strength ? color : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Text(
          'Password strength: $label',
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  
  Widget _buildPasswordRequirements() {
    final password = _passwordController.text;
    final hasMinLength = password.length >= 8;
    final hasUppercase = password.contains(RegExp(r'[A-Z]'));
    final hasLowercase = password.contains(RegExp(r'[a-z]'));
    final hasNumber = password.contains(RegExp(r'[0-9]'));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRequirementRow('At least 8 characters', hasMinLength),
        _buildRequirementRow('Uppercase letter (A-Z)', hasUppercase),
        _buildRequirementRow('Lowercase letter (a-z)', hasLowercase),
        _buildRequirementRow('Number (0-9)', hasNumber),
      ],
    );
  }
  
  Widget _buildRequirementRow(String requirement, bool met) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: met ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(
            requirement,
            style: TextStyle(
              fontSize: 12,
              color: met ? Colors.green : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}



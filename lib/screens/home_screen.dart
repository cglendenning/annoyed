import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../providers/auth_state_manager.dart';
import '../providers/annoyance_provider.dart';
import '../services/speech_service.dart';
import '../services/firebase_service.dart';
import '../widgets/tap_to_record_button.dart';
import '../widgets/animated_gradient_container.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';
import 'history_screen.dart';
import 'settings_screen.dart';
import 'coaching_screen.dart';
import 'coaching_screens/annoyance_analysis_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SpeechService _speechService = SpeechService();
  final TextEditingController _textController = TextEditingController();
  bool _isRecording = false;
  bool _isSaving = false;
  String _transcript = '';
  bool _isPremium = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkSubscriptionStatus();
  }
  
  Future<void> _checkSubscriptionStatus() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final hasActiveEntitlement = customerInfo.entitlements.all['premium']?.isActive == true;
      final hasActiveSub = customerInfo.activeSubscriptions.isNotEmpty;
      setState(() {
        _isPremium = hasActiveEntitlement || hasActiveSub;
      });
    } catch (e) {
      // Silently fail
    }
  }

  Future<void> _loadData() async {
    final authStateManager = Provider.of<AuthStateManager>(context, listen: false);
    final annoyanceProvider =
        Provider.of<AnnoyanceProvider>(context, listen: false);

    final uid = authStateManager.userId;
    if (uid != null) {
      await annoyanceProvider.loadAnnoyances(uid);
    }
  }

  void _startRecording() async {
    setState(() {
      _isRecording = true;
      _transcript = '';
    });

    try {
      await _speechService.startListening(
        onResult: (text) {
          setState(() {
            _transcript = text;
          });
        },
        onComplete: () {
          _stopRecording();
        },
      );
    } catch (e) {
      // Handle different error types
      setState(() {
        _isRecording = false;
        _transcript = '';
      });
      
      debugPrint('Speech error FULL: $e');
      debugPrint('Speech error type: ${e.runtimeType}');
      
      if (mounted) {
        final errorMessage = e.toString();
        debugPrint('Speech error message: $errorMessage');
        
        // Check if it's actually a permission error
        if (errorMessage.toLowerCase().contains('permission') || 
            errorMessage.toLowerCase().contains('not available')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Microphone permission is required to record'),
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Settings',
                onPressed: () async {
                  await openAppSettings();
                },
              ),
            ),
          );
        } else {
          // Show the actual error for debugging
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Debug: $errorMessage'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    }
  }

  void _stopRecording() async {
    await _speechService.stopListening();
    setState(() {
      _isRecording = false;
    });

    if (_transcript.isNotEmpty) {
      await _saveAnnoyance(_transcript);
    }
  }

  void _cancelRecording() async {
    await _speechService.cancel();
    setState(() {
      _isRecording = false;
      _transcript = '';
    });
  }

  Future<void> _saveAnnoyance(String transcript) async {
    if (transcript.trim().isEmpty) return;
    
    // Validate length
    if (transcript.length > AppConstants.maxAnnoyanceLength) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Annoyance is too long (${transcript.length} characters). Maximum is ${AppConstants.maxAnnoyanceLength}.'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      setState(() {
        _transcript = '';
      });
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final authStateManager = Provider.of<AuthStateManager>(context, listen: false);
    final annoyanceProvider =
        Provider.of<AnnoyanceProvider>(context, listen: false);

    final uid = authStateManager.userId;
    debugPrint('[HomeScreen] Saving annoyance - uid: $uid, isAuthenticated: ${authStateManager.isAuthenticated}');
    
    if (uid != null && authStateManager.isAuthenticated) {
      // Show transcribing snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transcribing...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      final id = await annoyanceProvider.saveAnnoyance(
        uid: uid,
        transcript: transcript,
      );

      if (id != null && mounted) {
        // Show categorizing snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Categorizing...'),
            duration: Duration(seconds: 1),
          ),
        );

        // Wait a bit then show saved snackbar
        await Future.delayed(const Duration(milliseconds: AppConstants.snackbarShortDelayMs));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Saved'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
          
          final annoyanceCount = annoyanceProvider.annoyances.length;
          final isAnonymous = authStateManager.isAnonymous;
          
          // Check if user has reached the threshold and is still anonymous (trigger auth wall)
          if (annoyanceCount >= AppConstants.annoyancesForAuthGate && isAnonymous) {
            // Trigger auth wall via state manager - it will update the state
            // and AuthGate will automatically show the auth wall screen
            await authStateManager.triggerAuthWall();
            // No manual navigation needed! State change will trigger UI update
          }
          // Auto-generate coaching: after 1st annoyance, then every 5 NEW annoyances after that
          // Pattern: annoyance #1 -> coaching #1, annoyance #6 -> coaching #2, annoyance #11 -> coaching #3, etc.
          else if (await _shouldGenerateNewCoaching(uid, annoyanceCount)) {
            await Future.delayed(const Duration(milliseconds: 1500));
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => CoachingScreen(forceRegenerate: true),
                ),
              );
            }
          }
        }
      }
    } else {
      debugPrint('[HomeScreen] ERROR: Cannot save annoyance - no authenticated user!');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Not authenticated. Please restart the app.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }

    setState(() {
      _isSaving = false;
      _transcript = '';
    });
  }

  void _submitTextEntry() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    await _saveAnnoyance(text);
    _textController.clear();
  }
  
  Future<bool> _shouldGenerateNewCoaching(String uid, int currentAnnoyanceCount) async {
    // Get count of existing coachings
    final coachings = await FirebaseService.getAllCoachings(uid: uid);
    final coachingCount = coachings.length;
    
    // First coaching should happen at annoyance #1
    if (coachingCount == 0 && currentAnnoyanceCount == 1) {
      return true;
    }
    
    // After that, generate coaching every N annoyances
    // Coaching #1 at annoyance 1, #2 at annoyance 6, #3 at annoyance 11, etc.
    // Formula: next coaching should be at annoyance count = 1 + (coachingCount * N)
    final nextCoachingAt = 1 + (coachingCount * AppConstants.annoyancesPerCoaching);
    
    return currentAnnoyanceCount == nextCoachingAt;
  }

  @override
  Widget build(BuildContext context) {
    final authStateManager = Provider.of<AuthStateManager>(context);
    final annoyanceProvider = Provider.of<AnnoyanceProvider>(context);
    final isAnonymous = authStateManager.isAnonymous;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Annoyed',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          // Sign out button (moved further left)
          if (!isAnonymous)
            IconButton(
              icon: ShaderMask(
                shaderCallback: (bounds) => LinearGradient(
                  colors: [AppColors.primaryTeal, AppColors.accentCoral],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ).createShader(bounds),
                child: const Icon(
                  Icons.account_circle,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              onPressed: () => _showSignOutDialog(context),
            ),
          // Premium indicator (no sign-in button for anonymous users - they'll hit auth wall at 5 annoyances)
          if (!isAnonymous && _isPremium)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryTeal, AppColors.accentCoral],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.stars, color: Colors.white, size: 14),
                    SizedBox(width: 4),
                    Text(
                      'Premium',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tap to record button
              TapToRecordButton(
                isRecording: _isRecording,
                isSaving: _isSaving,
                transcript: _transcript,
                onStartRecording: _startRecording,
                onStopRecording: _stopRecording,
                onCancelRecording: _cancelRecording,
                maxDurationSeconds: AppConstants.maxRecordingSeconds,
              ),

              const SizedBox(height: 12),

              // Type instead option (hide during recording/saving)
              if (!_isRecording && !_isSaving)
                Center(
                  child: TextButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Type Instead'),
                          content: TextField(
                            controller: _textController,
                            decoration: const InputDecoration(
                              hintText: 'What annoyed you?',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                            autofocus: true,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _submitTextEntry();
                              },
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('Type instead'),
                  ),
                ),

              const SizedBox(height: 24),

              // Coaching section - only show if user has entries
              if (!_isRecording && !_isSaving && annoyanceProvider.annoyances.isNotEmpty) ...[
                // Divider with text
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.grey.shade200,
                              Colors.grey.shade400,
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'YOUR INSIGHTS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.grey.shade400,
                              Colors.grey.shade200,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Enhanced Coaching button
                Stack(
                  children: [
                    // Glow effect
                    Container(
                      width: double.infinity,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentCoral.withValues(alpha: 0.3),
                            blurRadius: 40,
                            spreadRadius: -5,
                            offset: const Offset(0, 10),
                          ),
                          BoxShadow(
                            color: AppColors.primaryTeal.withValues(alpha: 0.2),
                            blurRadius: 30,
                            spreadRadius: 0,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                    ),
                    
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedGradientContainer(
                        colors: const [
                          AppColors.primaryTealLight,
                          AppColors.primaryTeal,
                          AppColors.accentCoral,
                          AppColors.primaryTeal,
                        ],
                        duration: const Duration(seconds: 5),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const CoachingScreen(),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Row(
                                  children: [
                                    // Premium icon with sparkle
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(14),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.25),
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.white.withValues(alpha: 0.3),
                                                blurRadius: 15,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.auto_awesome,
                                            color: Colors.white,
                                            size: 32,
                                          ),
                                        ),
                                        // Sparkle badge
                                        Positioned(
                                          top: -4,
                                          right: -4,
                                          child: Container(
                                            padding: const EdgeInsets.all(4),
                                            decoration: const BoxDecoration(
                                              color: AppColors.accentCoral,
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.star,
                                              color: Colors.white,
                                              size: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    
                                    const SizedBox(width: 20),
                                    
                                    // Text content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              const Text(
                                                'Get Your Coaching',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: -0.5,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 8,
                                                  vertical: 3,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withValues(alpha: 0.25),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Text(
                                                  'AI',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          const Text(
                                            'Breakthrough insights waiting for you ✨',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              height: 1.3,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // Arrow with glow
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.arrow_forward,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
              ],

              const Spacer(),

              // Bottom buttons
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final uid = authStateManager.userId;
                        if (uid != null) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => AnnoyanceAnalysisScreen(
                                uid: uid,
                                annoyanceProvider: annoyanceProvider,
                                isStandalone: true,
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.analytics_outlined),
                      label: const Text('Profile'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const HistoryScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.history),
                      label: const Text('History'),
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

  void _showSignOutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _signOut();
              },
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _signOut() async {
    try {
      final authStateManager = Provider.of<AuthStateManager>(context, listen: false);
      await authStateManager.signOut();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed out successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign out failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}


import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_state_manager.dart';
import '../providers/annoyance_provider.dart';
import '../services/firebase_service.dart';
import '../services/analytics_service.dart';
import '../services/paywall_service.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';
import 'paywall_screen.dart';
import 'coaching_history_screen.dart';

class CoachingScreen extends StatefulWidget {
  final bool forceRegenerate;
  
  const CoachingScreen({super.key, this.forceRegenerate = false});

  @override
  State<CoachingScreen> createState() => _CoachingScreenState();
}

class _CoachingScreenState extends State<CoachingScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _hasGivenFeedback = false;
  bool _hasCommitted = false; // Commitment gate
  String? _error;
  Map<String, dynamic>? _coaching;
  int _loadingMessageIndex = 0;
  late AnimationController _animationController;
  bool _isGenerating = false; // Prevent concurrent generation
  
  final List<String> _loadingMessages = [
    'Analyzing your patterns privately on our secure servers...',
    'Finding connections in your entries...',
    'Crafting personalized insights just for you...',
    'Your data stays encrypted and private...',
    'Almost there...',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
    _startLoadingMessages();
    _checkIfFirstCoaching();
  }
  
  // Check if this is the first coaching to skip commitment gate
  Future<void> _checkIfFirstCoaching() async {
    final authStateManager = Provider.of<AuthStateManager>(context, listen: false);
    final uid = authStateManager.userId;
    
    if (uid != null) {
      try {
        final coachings = await FirebaseService.getAllCoachings(uid: uid);
        if (coachings.isEmpty) {
          // This is the first coaching - skip commitment gate AND force regeneration
          debugPrint('[CoachingScreen] First coaching detected - skipping commitment gate and forcing regeneration');
          setState(() {
            _hasCommitted = true;
          });
          // Force regeneration to ensure educational content is generated
          _loadCoaching(forceRegenerate: true);
          return;
        }
      } catch (e) {
        debugPrint('[CoachingScreen] Error checking coaching count: $e');
      }
    }
    
    _loadCoaching(forceRegenerate: widget.forceRegenerate);
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  void _startLoadingMessages() {
    int iterations = 0;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));
      iterations++;
      
      // Timeout after max iterations to prevent infinite loop
      if (iterations >= AppConstants.maxLoadingMessageIterations) {
        if (mounted && _isLoading) {
          setState(() {
            _error = 'Request timed out. Please try again.';
            _isLoading = false;
          });
        }
        return false;
      }
      
      if (_isLoading && mounted) {
        setState(() {
          _loadingMessageIndex = (_loadingMessageIndex + 1) % _loadingMessages.length;
        });
        return true;
      }
      return false;
    });
  }

  Future<void> _loadCoaching({bool forceRegenerate = false}) async {
    debugPrint('[CoachingScreen] Loading coaching at ${DateTime.now()}, forceRegenerate: $forceRegenerate');
    
    // Prevent concurrent generation requests
    if (_isGenerating) {
      debugPrint('[CoachingScreen] Already generating, ignoring duplicate request');
      return;
    }
    
    setState(() {
      _isLoading = true;
      _error = null;
      _isGenerating = true;
    });

    final authStateManager = Provider.of<AuthStateManager>(context, listen: false);
    final uid = authStateManager.userId;

    if (uid == null) {
      setState(() {
        _error = 'Not authenticated';
        _isLoading = false;
        _isGenerating = false;
      });
      return;
    }

    try {
      // Check if we should generate a new coaching based on annoyances since last coaching
      if (!forceRegenerate) {
        final annoyanceProvider = Provider.of<AnnoyanceProvider>(context, listen: false);
        
        // Ensure annoyances are loaded
        await annoyanceProvider.loadAnnoyances(uid);
        
        final coachings = await FirebaseService.getAllCoachings(uid: uid);
        
        bool shouldGenerateNew = false;
        
        debugPrint('[CoachingScreen] DEBUG - Total annoyances loaded: ${annoyanceProvider.annoyances.length}');
        debugPrint('[CoachingScreen] DEBUG - Total coachings: ${coachings.length}');
        
        if (coachings.isEmpty) {
          // No coaching yet - generate first one if there's at least 1 annoyance
          if (annoyanceProvider.annoyances.isNotEmpty) {
            shouldGenerateNew = true;
            debugPrint('[CoachingScreen] First coaching needed');
          }
        } else {
          // Check annoyances created after the most recent coaching
          final mostRecentCoaching = coachings.first;
          // Handle both DateTime and Timestamp types
          DateTime? coachingTimestamp;
          final tsField = mostRecentCoaching['ts'] ?? mostRecentCoaching['timestamp'];
          
          if (tsField != null) {
            if (tsField is DateTime) {
              coachingTimestamp = tsField;
            } else if (tsField.toString().contains('Timestamp')) {
              // It's a Firestore Timestamp
              coachingTimestamp = tsField.toDate();
            }
          }
          
          debugPrint('[CoachingScreen] DEBUG - Most recent coaching timestamp: $coachingTimestamp');
          
          if (coachingTimestamp != null) {
            // Count annoyances with timestamp after the most recent coaching
            final newAnnoyances = annoyanceProvider.annoyances
                .where((annoyance) => annoyance.timestamp.isAfter(coachingTimestamp!))
                .toList();
            
            debugPrint('[CoachingScreen] DEBUG - Annoyances after coaching timestamp:');
            for (var annoyance in newAnnoyances.take(5)) {
              debugPrint('  - ${annoyance.timestamp}: ${annoyance.transcript.substring(0, annoyance.transcript.length > 30 ? 30 : annoyance.transcript.length)}...');
            }
            
            final newAnnoyancesSinceCoaching = newAnnoyances.length;            
            debugPrint('[CoachingScreen] DEBUG - New annoyances since coaching: $newAnnoyancesSinceCoaching');
            
            if (newAnnoyancesSinceCoaching >= AppConstants.newAnnoyancesForCoachingRegeneration) {
              shouldGenerateNew = true;
              debugPrint('[CoachingScreen] ✓ New coaching due: $newAnnoyancesSinceCoaching new annoyances since last coaching');
            } else {
              debugPrint('[CoachingScreen] ✗ Not enough new annoyances yet ($newAnnoyancesSinceCoaching/${AppConstants.newAnnoyancesForCoachingRegeneration})');
            }
          }
        }
        
        if (shouldGenerateNew) {
          debugPrint('[CoachingScreen] Forcing regeneration due to threshold');
          forceRegenerate = true;
        } else if (coachings.isNotEmpty) {
          // Use the most recent coaching
          final mostRecent = coachings.first;
          debugPrint('[CoachingScreen] Loaded most recent coaching from history');
          
          if (mounted) {
            setState(() {
              _coaching = {
                'recommendation': mostRecent['recommendation'],
                'type': mostRecent['type'],
                'explanation': mostRecent['explanation'] ?? '',
              };
              _isLoading = false;
              _isGenerating = false;
            });
            await AnalyticsService.logEvent('coaching_viewed');
          }
          return;
        }
      }
      
      // If no coaching exists or forced regenerate, generate a new one
      debugPrint('[CoachingScreen] Generating new coaching for uid: $uid');
      final result = await FirebaseService.generateCoaching(uid: uid);
      debugPrint('[CoachingScreen] Received result: ${result['recommendation']?.substring(0, 50)}...');
      
      // Save coaching immediately so it doesn't regenerate on next view
      await FirebaseService.saveCoachingResonance(
        uid: uid,
        recommendation: result['recommendation'],
        type: result['type'],
        resonance: '', // Empty until user provides feedback
        explanation: result['explanation'] ?? '',
      );
      debugPrint('[CoachingScreen] Saved coaching to Firestore');
      
      if (mounted) {
        setState(() {
          _coaching = result;
          _isLoading = false;
          _isGenerating = false;
        });
        
        await AnalyticsService.logEvent('coaching_viewed');
      }
    } catch (e) {
      debugPrint('[CoachingScreen] Error: $e');
      // Extract meaningful error message from Firebase Functions errors
      String errorMsg = e.toString();
      
      // Try to extract clean error message from various Firebase error formats
      if (errorMsg.contains('message:')) {
        // Firebase Functions error format: [cloud_functions/...] message: actual error
        final match = RegExp(r'message:\s*(.+?)(?:\s*(?:\(|$))').firstMatch(errorMsg);
        if (match != null) {
          errorMsg = match.group(1)?.trim() ?? errorMsg;
        }
      } else if (errorMsg.contains(']')) {
        // Try to extract message after error code
        final parts = errorMsg.split(']');
        if (parts.length > 1) {
          errorMsg = parts[1].trim();
        }
      }
      
      // Check if it's a cost limit error
      if (errorMsg.contains('usage limit') || 
          errorMsg.contains('permission-denied') || 
          errorMsg.contains('resource-exhausted')) {
        // Show paywall for cost limit errors
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isGenerating = false;
          });
          
          // Get detailed usage message
          final usageMsg = await PaywallService.getUsageMessage(uid);
          
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => PaywallScreen(
                  message: usageMsg.isEmpty ? errorMsg : usageMsg,
                ),
              ),
            );
          }
        }
        return;
      }
      
      if (mounted) {
        setState(() {
          _error = errorMsg;
          _isLoading = false;
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _handleResonance(String resonance) async {
    if (_coaching == null || _hasGivenFeedback) return;

    final authStateManager = Provider.of<AuthStateManager>(context, listen: false);
    final uid = authStateManager.userId;

    if (uid != null) {
      try {
        // Save coaching with user's resonance feedback
        await FirebaseService.saveCoachingResonance(
          uid: uid,
          recommendation: _coaching!['recommendation'],
          type: _coaching!['type'],
          resonance: resonance,
          explanation: _coaching!['explanation'] ?? '',
        );

        setState(() {
          _hasGivenFeedback = true;
        });

        await AnalyticsService.logEvent('coaching_resonance_$resonance');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                resonance == 'hell_yes'
                    ? '🎉 Awesome! Keep us posted on how it goes'
                    : 'Got it. We\'ll adjust future recommendations',
              ),
              backgroundColor: resonance == 'hell_yes' ? Colors.green : Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );

          // Auto-close after feedback
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              Navigator.of(context).pop();
            }
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving feedback: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F766E), // Immersive background
      appBar: _hasCommitted ? AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (!_isLoading && _error == null) ...[
            IconButton(
              icon: const Icon(Icons.history, color: Colors.white),
              tooltip: 'View coaching history',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const CoachingHistoryScreen(),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: 'Generate new coaching',
              onPressed: () async {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                setState(() {
                  _hasGivenFeedback = false;
                  _loadingMessageIndex = 0;
                });
                await _loadCoaching(forceRegenerate: true);
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Generated new coaching'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
          ],
        ],
      ) : null,
      body: !_hasCommitted
          ? _buildCommitmentGate()
          : _isLoading
              ? _buildBeautifulLoadingState()
              : _error != null
                  ? _buildErrorState()
                  : _buildCoachingContent(),
    );
  }
  
  Widget _buildCommitmentGate() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0F766E),
            const Color(0xFF0F766E).withValues(alpha: 0.8),
            AppColors.primaryTealDark,
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Glowing icon
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withValues(alpha: 0.3),
                      blurRadius: 50,
                      spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.self_improvement,
                  size: 80,
                  color: Colors.white,
                ),
              ),
              
              const SizedBox(height: 48),
              
              const Text(
                'Before We Begin...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                  letterSpacing: 2,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              const Text(
                'Can you commit to 5 minutes of uninterrupted deep work on yourself right now?',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.3,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 24),
              
              Text(
                'No transformation can happen if you\'re distracted.',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 64),
              
              // Yes button
              SizedBox(
                width: double.infinity,
                height: 64,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _hasCommitted = true;
                    });
                    _loadCoaching(forceRegenerate: widget.forceRegenerate);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0F766E),
                    elevation: 8,
                    shadowColor: Colors.black.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Yes, I\'m Ready',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Not now button
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white.withValues(alpha: 0.7),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                ),
                child: const Text(
                  'Not now, I\'ll come back later',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBeautifulLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated gradient circle
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _animationController.value * 2 * 3.14159,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Colors.white24,
                          Colors.white,
                          AppColors.accentCoralLight,
                          Colors.white,
                          Colors.white24,
                        ],
                        stops: [0.0, 0.25, 0.5, 0.75, 1.0],
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0F766E),
                        ),
                        child: const Icon(
                          Icons.psychology,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            
            const SizedBox(height: 40),
            
            // Cycling loading messages
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: Text(
                _loadingMessages[_loadingMessageIndex],
                key: ValueKey(_loadingMessageIndex),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Text(
              'Coach Craig is reviewing your patterns',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _error!.contains('No annoyances')
                  ? 'Record at least 3 annoyances to get personalized coaching'
                  : 'Error: $_error',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoachingContent() {
    if (_coaching == null) {
      return const Center(child: Text('No coaching available', style: TextStyle(color: Colors.white)));
    }

    final recommendation = _coaching!['recommendation'] ?? '';
    final explanation = _coaching!['explanation'] ?? '';
    final isFirstCoaching = _coaching!['isFirstCoaching'] == true;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0F766E),
            const Color(0xFF0F766E).withValues(alpha: 0.95),
            AppColors.primaryTealDark,
          ],
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Dynamic hero section with annoyance count
            _buildDynamicHeroSection(isFirstCoaching),

            // Annoyance count indicator
            _buildAnnoyanceCountIndicator(),

            // Main content with varied formatting
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Mindset Shift with enhanced formatting
                  _buildEnhancedMindsetCard(recommendation),

                  const SizedBox(height: 24),

                  // Action Step with varied, engaging presentation
                  _buildVariedActionStepContent(explanation),

                  const SizedBox(height: 32),

                  // Resonance section with enhanced design
                  _buildEnhancedResonanceSection(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnoyanceCountIndicator() {
    return FutureBuilder<int>(
      future: _getAnnoyanceCount(),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final count = snapshot.data!;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Analyzed $count ${count == 1 ? 'annoyance' : 'annoyances'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Pattern Analysis',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Future<int> _getAnnoyanceCount() async {
    try {
      final authStateManager = Provider.of<AuthStateManager>(context, listen: false);
      final uid = authStateManager.userId;
      if (uid != null) {
        final annoyanceProvider = Provider.of<AnnoyanceProvider>(context, listen: false);
        await annoyanceProvider.loadAnnoyances(uid);
        return annoyanceProvider.annoyances.length;
      }
    } catch (e) {
      debugPrint('Error getting annoyance count: $e');
    }
    return 0;
  }

  Widget _buildDynamicHeroSection(bool isFirstCoaching) {
    final heroVariations = [
      {
        'icon': Icons.auto_awesome,
        'badge': 'YOUR BREAKTHROUGH',
        'color': AppColors.accentCoral,
        'message': 'Here\'s what I see in your patterns...'
      },
      {
        'icon': Icons.psychology,
        'badge': 'INSIGHT UNLOCKED',
        'color': Colors.purple,
        'message': 'Let\'s shift your perspective...'
      },
      {
        'icon': Icons.bolt,
        'badge': 'READY TO ACT',
        'color': Colors.orange,
        'message': 'Time to make a real change...'
      },
      {
        'icon': Icons.lightbulb,
        'badge': 'AHA MOMENT',
        'color': Colors.amber,
        'message': 'I found the pattern in your data...'
      }
    ];
    
    final variation = heroVariations[DateTime.now().millisecondsSinceEpoch % heroVariations.length];
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Column(
        children: [
          // Animated badge
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 800),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: variation['color'] as Color,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: (variation['color'] as Color).withValues(alpha: 0.5),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Text(
                    variation['badge'] as String,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 32),
          
          // Dynamic icon with animation
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1200),
            tween: Tween(begin: 0.0, end: 1.0),
            builder: (context, value, child) {
              return Transform.scale(
                scale: value,
                child: Icon(
                  variation['icon'] as IconData,
                  size: 80,
                  color: Colors.white,
                ),
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          // Dynamic message
          Text(
            variation['message'] as String,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedMindsetCard(String content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF8FAFC),
            Color(0xFFE2E8F0),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.psychology,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'MINDSET SHIFT',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'A new way of thinking',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Content with enhanced formatting
          _buildFormattedContent(content, isActionStep: false),
        ],
      ),
    );
  }

  Widget _buildVariedActionStepContent(String content) {
    // Parse content into sections for varied presentation
    final sections = _parseContentIntoSections(content);
    
    // Choose a random presentation style for variety
    final presentationStyles = [
      _buildActionStepStyle1,
      _buildActionStepStyle2,
      _buildActionStepStyle3,
      _buildActionStepStyle4,
      _buildActionStepStyle5,
    ];
    
    final randomStyle = presentationStyles[DateTime.now().millisecondsSinceEpoch % presentationStyles.length];
    return randomStyle(sections);
  }

  Widget _buildActionStepStyle1(List<ContentSection> sections) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF7ED),
            Color(0xFFFFEDD5),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.8),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and title
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.bolt,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ACTION STEP',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Something concrete to do today',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // First paragraph only
          if (sections.isNotEmpty && sections.first.content.isNotEmpty)
            _buildParagraphText(sections.first.content.first),
          
          const SizedBox(height: 20),
          
          // Rest as engaging cards
          ...sections.skip(1).map((section) => _buildEngagingSectionCard(section)),
        ],
      ),
    );
  }

  Widget _buildActionStepStyle2(List<ContentSection> sections) {
    return Column(
      children: [
        // Main action card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFF0F9FF),
                Color(0xFFE0F2FE),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0EA5E9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.play_circle_filled,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'YOUR ACTION',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (sections.isNotEmpty && sections.first.content.isNotEmpty)
                _buildParagraphText(sections.first.content.first),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Supporting cards
        ...sections.skip(1).map((section) => _buildSupportingCard(section)),
      ],
    );
  }

  Widget _buildActionStepStyle3(List<ContentSection> sections) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF0FDF4),
            Color(0xFFDCFCE7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF22C55E).withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.trending_up,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'IMPLEMENTATION',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (sections.isNotEmpty && sections.first.content.isNotEmpty)
            _buildParagraphText(sections.first.content.first),
          const SizedBox(height: 16),
          ...sections.skip(1).map((section) => _buildImplementationStep(section)),
        ],
      ),
    );
  }

  Widget _buildActionStepStyle4(List<ContentSection> sections) {
    return Column(
      children: [
        // Hero action
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFDF4FF),
                Color(0xFFF3E8FF),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFA855F7).withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA855F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.psychology,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'MINDSET + ACTION',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (sections.isNotEmpty && sections.first.content.isNotEmpty)
                _buildParagraphText(sections.first.content.first),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Grid of supporting elements
        _buildSupportingGrid(sections.skip(1).toList()),
      ],
    );
  }

  Widget _buildActionStepStyle5(List<ContentSection> sections) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF1F2),
            Color(0xFFFFE4E6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.flash_on,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'QUICK WIN',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E293B),
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (sections.isNotEmpty && sections.first.content.isNotEmpty)
            _buildParagraphText(sections.first.content.first),
          const SizedBox(height: 16),
          ...sections.skip(1).map((section) => _buildQuickWinElement(section)),
        ],
      ),
    );
  }

  Widget _buildParagraphText(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.6,
        color: Color(0xFF1E293B),
      ),
    );
  }

  Widget _buildEngagingSectionCard(ContentSection section) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (section.title.isNotEmpty) ...[
            Text(
              section.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 12),
          ],
          ...section.content.map((line) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              line,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                height: 1.5,
                color: Color(0xFF1E293B),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildSupportingCard(ContentSection section) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (section.title.isNotEmpty) ...[
            Text(
              section.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
          ],
          ...section.content.map((line) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              line,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
                color: Color(0xFF1E293B),
              ),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildImplementationStep(ContentSection section) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF22C55E).withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF22C55E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.check,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (section.title.isNotEmpty) ...[
                  Text(
                    section.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                ...section.content.map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    line,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportingGrid(List<ContentSection> sections) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final section = sections[index];
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(0xFFA855F7).withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (section.title.isNotEmpty) ...[
                Text(
                  section.title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Expanded(
                child: Text(
                  section.content.join(' '),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                    color: Color(0xFF1E293B),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 4,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickWinElement(ContentSection section) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFEF4444).withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.flash_on,
              color: Colors.white,
              size: 12,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (section.title.isNotEmpty) ...[
                  Text(
                    section.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                ...section.content.map((line) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    line,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormattedContent(String content, {required bool isActionStep}) {
    if (isActionStep) {
      return _buildVariedActionStepContent(content);
    } else {
      return _buildEnhancedMindsetContent(content);
    }
  }


  Widget _buildEnhancedMindsetContent(String content) {
    // Parse content for bullet points, emphasis, etc.
    final lines = content.split('\n');
    final formattedWidgets = <Widget>[];
    
    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      
      // Check for bullet points
      if (line.startsWith('•') || line.startsWith('-') || line.startsWith('*')) {
        formattedWidgets.add(
          Container(
            margin: const EdgeInsets.only(left: 16, bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 8, right: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    line.substring(1).trim(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      // Check for emphasis (text in quotes or caps)
      else if (line.contains('"') || line.toUpperCase() == line && line.length > 5) {
        formattedWidgets.add(
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              line,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                height: 1.4,
                color: const Color(0xFF1E293B),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        );
      }
      // Regular paragraph
      else {
        formattedWidgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              line,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.6,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
        );
      }
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: formattedWidgets,
    );
  }

  List<ContentSection> _parseContentIntoSections(String content) {
    final sections = <ContentSection>[];
    final lines = content.split('\n');
    
    ContentSection? currentSection;
    
    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;
      
      // Check for section headers (all caps, short lines, or lines ending with :)
      if (_isSectionHeader(trimmedLine)) {
        if (currentSection != null) {
          sections.add(currentSection);
        }
        currentSection = ContentSection(
          type: _determineSectionType(trimmedLine),
          title: trimmedLine,
          content: [],
        );
      } else if (currentSection != null) {
        currentSection.content.add(trimmedLine);
      } else {
        // No section header yet, create a default one
        currentSection = ContentSection(
          type: ContentSectionType.paragraph,
          title: '',
          content: [trimmedLine],
        );
      }
    }
    
    if (currentSection != null) {
      sections.add(currentSection);
    }
    
    // If no sections were created, create a default one
    if (sections.isEmpty) {
      sections.add(ContentSection(
        type: ContentSectionType.paragraph,
        title: '',
        content: content.split('\n').where((line) => line.trim().isNotEmpty).toList(),
      ));
    }
    
    return sections;
  }

  bool _isSectionHeader(String line) {
    // Check for common section header patterns
    return line.length < 50 && (
      line.toUpperCase() == line && line.length > 3 && line.length < 30 ||
      line.endsWith(':') ||
      line.startsWith('**') ||
      line.startsWith('##') ||
      line.startsWith('###')
    );
  }

  ContentSectionType _determineSectionType(String title) {
    final lowerTitle = title.toLowerCase();
    
    if (lowerTitle.contains('step') || lowerTitle.contains('action') || lowerTitle.contains('do')) {
      return ContentSectionType.actionSteps;
    } else if (lowerTitle.contains('why') || lowerTitle.contains('reason') || lowerTitle.contains('because')) {
      return ContentSectionType.explanation;
    } else if (lowerTitle.contains('tip') || lowerTitle.contains('hint') || lowerTitle.contains('remember')) {
      return ContentSectionType.tips;
    } else if (lowerTitle.contains('example') || lowerTitle.contains('scenario')) {
      return ContentSectionType.examples;
    } else {
      return ContentSectionType.paragraph;
    }
  }


  Widget _buildEnhancedResonanceSection() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          const Text(
            'How does this land?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 24),
          
          if (!_hasGivenFeedback)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleResonance('meh'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      side: const BorderSide(color: Colors.white54, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Meh',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: () => _handleResonance('hell_yes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF0F766E),
                      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Hell YESSS!',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.check_circle, size: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Text(
                    'Feedback received!',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

enum ContentSectionType {
  actionSteps,
  explanation,
  tips,
  examples,
  paragraph,
}

class ContentSection {
  final ContentSectionType type;
  final String title;
  final List<String> content;

  ContentSection({
    required this.type,
    required this.title,
    required this.content,
  });
}

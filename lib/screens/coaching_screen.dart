import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/annoyance_provider.dart';
import '../services/firebase_service.dart';
import '../services/analytics_service.dart';
import '../services/paywall_service.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';
import '../widgets/animated_gradient_container.dart';
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
  bool _showExplanation = false;
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
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final uid = authProvider.userId;
    
    if (uid != null) {
      try {
        final coachings = await FirebaseService.getAllCoachings(uid: uid);
        if (coachings.isEmpty && widget.forceRegenerate) {
          // This is the first coaching - skip commitment gate
          debugPrint('[CoachingScreen] First coaching detected - skipping commitment gate');
          setState(() {
            _hasCommitted = true;
          });
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

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final uid = authProvider.userId;

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

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final uid = authProvider.userId;

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

  IconData _getTypeIcon() {
    if (_coaching == null) return Icons.lightbulb_outline;
    
    return _coaching!['type'] == 'mindset_shift' 
        ? Icons.psychology 
        : Icons.fitness_center;
  }

  String _getTypeLabel() {
    if (_coaching == null) return '';
    
    return _coaching!['type'] == 'mindset_shift' 
        ? 'Mindset Shift' 
        : 'Behavior Change';
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
                setState(() {
                  _hasGivenFeedback = false;
                  _showExplanation = false;
                  _loadingMessageIndex = 0;
                });
                await _loadCoaching(forceRegenerate: true);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
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
            const Color(0xFF0F766E).withOpacity(0.8),
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
                  color: Colors.white.withOpacity(0.15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.3),
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
                  color: Colors.white.withOpacity(0.9),
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
                    shadowColor: Colors.black.withOpacity(0.3),
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
                  foregroundColor: Colors.white.withOpacity(0.7),
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
                color: Colors.white.withOpacity(0.7),
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

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0F766E),
            const Color(0xFF0F766E).withOpacity(0.95),
            AppColors.primaryTealDark,
          ],
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // Hero section with dramatic visual
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.05),
                  ],
                ),
              ),
              child: Column(
                children: [
                  // Glowing badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.accentCoral,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentCoral.withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Text(
                      'YOUR BREAKTHROUGH',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  const Icon(
                    Icons.auto_awesome,
                    size: 80,
                    color: Colors.white,
                  ),
                ],
              ),
            ),

            // Main content
            Container(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  // Section 1: Mindset Shift
                  _buildInsightCard(
                    icon: Icons.psychology,
                    title: 'MINDSET SHIFT',
                    content: recommendation,
                    gradient: [
                      Colors.white,
                      const Color(0xFFFFF5F5),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Section 2: Behavior Change  
                  _buildInsightCard(
                    icon: Icons.bolt,
                    title: 'ACTION STEP',
                    content: explanation,
                    gradient: [
                      const Color(0xFFFFF5F5),
                      Colors.white,
                    ],
                  ),

                  const SizedBox(height: 48),

                  // Resonance section
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
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
                              color: Colors.white.withOpacity(0.2),
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
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightCard({
    required IconData icon,
    required String title,
    required String content,
    required List<Color> gradient,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryTeal, AppColors.accentCoral],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: Color(0xFF0F766E),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          Text(
            content,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              height: 1.5,
              color: Colors.black87,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}


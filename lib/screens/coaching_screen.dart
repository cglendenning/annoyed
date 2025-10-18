import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/annoyance_provider.dart';
import '../services/firebase_service.dart';
import '../services/analytics_service.dart';
import '../services/paywall_service.dart';
import '../utils/app_colors.dart';
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
  String? _error;
  Map<String, dynamic>? _coaching;
  int _loadingMessageIndex = 0;
  late AnimationController _animationController;
  
  final List<String> _loadingMessages = [
    'Analyzing your patterns...',
    'Finding connections...',
    'Crafting personalized insights...',
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
    _loadCoaching(forceRegenerate: widget.forceRegenerate);
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  void _startLoadingMessages() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 3));
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
    print('[CoachingScreen] Loading coaching at ${DateTime.now()}, forceRegenerate: $forceRegenerate');
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final uid = authProvider.userId;

    if (uid == null) {
      setState(() {
        _error = 'Not authenticated';
        _isLoading = false;
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
        
        print('[CoachingScreen] DEBUG - Total annoyances loaded: ${annoyanceProvider.annoyances.length}');
        print('[CoachingScreen] DEBUG - Total coachings: ${coachings.length}');
        
        if (coachings.isEmpty) {
          // No coaching yet - generate first one if there's at least 1 annoyance
          if (annoyanceProvider.annoyances.isNotEmpty) {
            shouldGenerateNew = true;
            print('[CoachingScreen] First coaching needed');
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
          
          print('[CoachingScreen] DEBUG - Most recent coaching timestamp: $coachingTimestamp');
          
          if (coachingTimestamp != null) {
            // Count annoyances with timestamp after the most recent coaching
            final newAnnoyances = annoyanceProvider.annoyances
                .where((annoyance) => annoyance.timestamp.isAfter(coachingTimestamp!))
                .toList();
            
            print('[CoachingScreen] DEBUG - Annoyances after coaching timestamp:');
            for (var annoyance in newAnnoyances.take(5)) {
              print('  - ${annoyance.timestamp}: ${annoyance.transcript.substring(0, annoyance.transcript.length > 30 ? 30 : annoyance.transcript.length)}...');
            }
            
            final newAnnoyancesSinceCoaching = newAnnoyances.length;
            print('[CoachingScreen] DEBUG - New annoyances since coaching: $newAnnoyancesSinceCoaching');
            
            if (newAnnoyancesSinceCoaching >= 5) {
              shouldGenerateNew = true;
              print('[CoachingScreen] ✓ New coaching due: $newAnnoyancesSinceCoaching new annoyances since last coaching');
            } else {
              print('[CoachingScreen] ✗ Not enough new annoyances yet ($newAnnoyancesSinceCoaching/5)');
            }
          }
        }
        
        if (shouldGenerateNew) {
          print('[CoachingScreen] Forcing regeneration due to threshold');
          forceRegenerate = true;
        } else if (coachings.isNotEmpty) {
          // Use the most recent coaching
          final mostRecent = coachings.first;
          print('[CoachingScreen] Loaded most recent coaching from history');
          
          if (mounted) {
            setState(() {
              _coaching = {
                'recommendation': mostRecent['recommendation'],
                'type': mostRecent['type'],
                'explanation': mostRecent['explanation'] ?? '',
              };
              _isLoading = false;
            });
            await AnalyticsService.logEvent('coaching_viewed');
          }
          return;
        }
      }
      
      // If no coaching exists or forced regenerate, generate a new one
      print('[CoachingScreen] Generating new coaching for uid: $uid');
      final result = await FirebaseService.generateCoaching(uid: uid);
      print('[CoachingScreen] Received result: ${result['recommendation']?.substring(0, 50)}...');
      
      if (mounted) {
        setState(() {
          _coaching = result;
          _isLoading = false;
        });
        
        // Note: Coaching will be saved to Firestore when user provides feedback (hell_yes/meh)
        // or when they view it from history. We don't save immediately to avoid duplicates.
        
        await AnalyticsService.logEvent('coaching_viewed');
      }
    } catch (e) {
      print('[CoachingScreen] Error: $e');
      // Extract meaningful error message
      String errorMsg = e.toString();
      if (errorMsg.contains('message:')) {
        // Extract the actual error message from Firebase error
        final match = RegExp(r'message:\s*(.+?)(?:\n|$)').firstMatch(errorMsg);
        if (match != null) {
          errorMsg = match.group(1) ?? errorMsg;
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
      appBar: AppBar(
        title: const Text('Your Coaching'),
        actions: [
          if (!_isLoading && _error == null) ...[
            IconButton(
              icon: const Icon(Icons.history),
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
              icon: const Icon(Icons.refresh),
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
      ),
      body: _isLoading
          ? _buildBeautifulLoadingState()
          : _error != null
              ? _buildErrorState()
              : _buildCoachingContent(),
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
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: const [
                          AppColors.primaryTealLight,
                          AppColors.primaryTeal,
                          AppColors.accentCoral,
                          AppColors.accentCoralLight,
                          AppColors.primaryTealLight,
                        ],
                        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).scaffoldBackgroundColor,
                        ),
                        child: const Icon(
                          Icons.psychology,
                          size: 48,
                          color: AppColors.primaryTeal,
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
                  color: AppColors.primaryTeal,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 16),
            
            Text(
              'Coach Craig is reviewing your patterns',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
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
      return const Center(child: Text('No coaching available'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon and type
          Center(
            child: Column(
              children: [
                ClipOval(
                  child: AnimatedGradientContainer(
                    colors: const [
                      AppColors.primaryTealLight,
                      AppColors.primaryTeal,
                      AppColors.accentCoralLight,
                    ],
                    duration: const Duration(seconds: 5),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      child: Icon(
                        _getTypeIcon(),
                        size: 48,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryTealLight.withAlpha(26), // ~10%
                        AppColors.accentCoralLight.withAlpha(26), // ~10%
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ShaderMask(
                    shaderCallback: (bounds) => AppColors.primaryGradient.createShader(bounds),
                    child: Text(
                      _getTypeLabel(),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Recommendation
          const Text(
            'Your Fix',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _coaching!['recommendation'] ?? '',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 32),

          // Explanation (initially hidden)
          if (!_showExplanation)
            Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _showExplanation = true;
                  });
                  AnalyticsService.logEvent('coaching_explain_more');
                },
                icon: const Icon(Icons.arrow_downward),
                label: const Text('Explain more'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF0F766E),
                ),
              ),
            ),

          if (_showExplanation) ...[
            const Divider(height: 32),
            Text(
              _coaching!['explanation'] ?? '',
              style: const TextStyle(
                fontSize: 16,
                height: 1.6,
              ),
            ),
          ],

          const SizedBox(height: 32),

          // Resonance buttons
          if (!_hasGivenFeedback) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _handleResonance('meh'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey.shade300, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Meh.',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _handleResonance('hell_yes'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'HELL Yes!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}


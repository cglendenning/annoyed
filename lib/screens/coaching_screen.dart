import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/firebase_service.dart';
import '../services/analytics_service.dart';

class CoachingScreen extends StatefulWidget {
  const CoachingScreen({super.key});

  @override
  State<CoachingScreen> createState() => _CoachingScreenState();
}

class _CoachingScreenState extends State<CoachingScreen> {
  bool _isLoading = true;
  bool _showExplanation = false;
  bool _hasGivenFeedback = false;
  String? _error;
  Map<String, dynamic>? _coaching;

  @override
  void initState() {
    super.initState();
    _loadCoaching();
  }

  Future<void> _loadCoaching() async {
    print('[CoachingScreen] Loading coaching at ${DateTime.now()}');
    
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
      print('[CoachingScreen] Calling FirebaseService.generateCoaching for uid: $uid');
      final result = await FirebaseService.generateCoaching(uid: uid);
      print('[CoachingScreen] Received result: ${result['recommendation']?.substring(0, 50)}...');
      
      if (mounted) {
        setState(() {
          _coaching = result;
          _isLoading = false;
        });
        
        // Save the recommendation immediately (without feedback) so regenerate knows what was shown
        await FirebaseService.saveCoachingResonance(
          uid: uid,
          recommendation: result['recommendation'],
          type: result['type'],
          resonance: '', // Empty means no feedback yet
        );
        
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

    setState(() {
      _hasGivenFeedback = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final uid = authProvider.userId;

    if (uid != null) {
      try {
        await FirebaseService.saveCoachingResonance(
          uid: uid,
          recommendation: _coaching!['recommendation'],
          type: _coaching!['type'],
          resonance: resonance,
        );

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
          setState(() {
            _hasGivenFeedback = false;
          });
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
        title: const Text('Your Fix'),
        actions: [
          if (!_isLoading && _error == null)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Generate new fix',
              onPressed: () async {
                setState(() {
                  _hasGivenFeedback = false;
                  _showExplanation = false;
                });
                await _loadCoaching();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Generated new fix'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                }
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildErrorState()
              : _buildCoachingContent(),
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
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D9CDB).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getTypeIcon(),
                    size: 48,
                    color: const Color(0xFF2D9CDB),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2D9CDB).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getTypeLabel(),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2D9CDB),
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
                  foregroundColor: const Color(0xFF2D9CDB),
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
                      backgroundColor: const Color(0xFF2D9CDB),
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
          ] else ...[
            const Center(
              child: CircularProgressIndicator(),
            ),
          ],
        ],
      ),
    );
  }
}


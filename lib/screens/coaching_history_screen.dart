import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_state_manager.dart';
import '../services/firebase_service.dart';
import '../utils/app_colors.dart';

class CoachingHistoryScreen extends StatefulWidget {
  const CoachingHistoryScreen({super.key});

  @override
  State<CoachingHistoryScreen> createState() => _CoachingHistoryScreenState();
}

class _CoachingHistoryScreenState extends State<CoachingHistoryScreen> {
  List<Map<String, dynamic>> _coachings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCoachings();
  }

  Future<void> _loadCoachings() async {
    setState(() {
      _isLoading = true;
    });

    final authStateManager = Provider.of<AuthStateManager>(context, listen: false);
    final uid = authStateManager.userId;

    if (uid != null) {
      try {
        final coachings = await FirebaseService.getAllCoachings(uid: uid);
        if (mounted) {
          setState(() {
            _coachings = coachings;
            _isLoading = false;
          });
        }
      } catch (e) {
        debugPrint('Error loading coachings: $e');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    try {
      final DateTime date = timestamp.toDate();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today at ${DateFormat('h:mm a').format(date)}';
      } else if (difference.inDays == 1) {
        return 'Yesterday at ${DateFormat('h:mm a').format(date)}';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return DateFormat('MMM d, y').format(date);
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  IconData _getTypeIcon(String type) {
    return type == 'mindset_shift' ? Icons.psychology : Icons.fitness_center;
  }

  String _getTypeLabel(String type) {
    return type == 'mindset_shift' ? 'Mindset Shift' : 'Behavior Change';
  }

  Future<void> _toggleHeart(Map<String, dynamic> coaching) async {
    final authStateManager = Provider.of<AuthStateManager>(context, listen: false);
    final uid = authStateManager.userId;
    
    if (uid == null) return;

    final currentResonance = coaching['resonance'];
    final newResonance = currentResonance == 'hell_yes' ? '' : 'hell_yes';

    try {
      // Optimistically update UI
      setState(() {
        coaching['resonance'] = newResonance;
      });

      // Save to Firebase
      await FirebaseService.saveCoachingResonance(
        uid: uid,
        recommendation: coaching['recommendation'],
        type: coaching['type'],
        resonance: newResonance,
        explanation: coaching['explanation'] ?? '',
      );
    } catch (e) {
      // Revert on error
      setState(() {
        coaching['resonance'] = currentResonance;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coaching History'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _coachings.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _coachings.length,
                  itemBuilder: (context, index) {
                    final coaching = _coachings[index];
                    return _buildCoachingCard(coaching);
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 24),
            Text(
              'No coaching history yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Record some annoyances to get personalized coaching',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoachingCard(Map<String, dynamic> coaching) {
    final type = coaching['type'] ?? 'mindset_shift';
    final recommendation = coaching['recommendation'] ?? '';
    final explanation = coaching['explanation'] ?? '';
    final resonance = coaching['resonance'];
    final timestamp = coaching['ts'];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          _showCoachingDetail(coaching);
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with type and date
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTealLight.withAlpha(51),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _getTypeIcon(type),
                      color: AppColors.primaryTeal,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getTypeLabel(type),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryTeal,
                          ),
                        ),
                        Text(
                          _formatDate(timestamp),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      resonance == 'hell_yes' ? Icons.favorite : Icons.favorite_border,
                      color: resonance == 'hell_yes' ? Colors.red : Colors.grey.shade400,
                      size: 24,
                    ),
                    onPressed: () => _toggleHeart(coaching),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Recommendation preview
              Text(
                recommendation,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 12),
              
              // Explanation preview
              if (explanation.isNotEmpty)
                Text(
                  explanation,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              
              const SizedBox(height: 12),
              
              // Tap to read more
              Row(
                children: [
                  const Spacer(),
                  Text(
                    'Tap to read full coaching',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.primaryTeal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 12,
                    color: AppColors.primaryTeal,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCoachingDetail(Map<String, dynamic> coaching) {
    final type = coaching['type'] ?? 'mindset_shift';
    final recommendation = coaching['recommendation'] ?? '';
    final explanation = coaching['explanation'] ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryTealLight.withAlpha(51),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getTypeIcon(type),
                              color: AppColors.primaryTeal,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _getTypeLabel(type),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryTeal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 20),
                      
                      // Recommendation
                      Text(
                        recommendation,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          height: 1.4,
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      const Divider(),
                      
                      const SizedBox(height: 24),
                      
                      // Explanation
                      Text(
                        explanation,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.7,
                          color: Colors.black87,
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


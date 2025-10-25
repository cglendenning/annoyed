import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'dart:io';
import '../providers/auth_state_manager.dart';
import '../services/firebase_service.dart';
import '../utils/app_colors.dart';
import 'coaching_flow_screen.dart';

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
    final docId = coaching['id'];
    if (docId == null) {
      debugPrint('[CoachingHistory] ❌ No document ID found for coaching');
      return;
    }

    final currentResonance = coaching['resonance'] ?? '';
    // Cycle through: none -> hell_yes -> meh -> none
    String newResonance;
    if (currentResonance == '' || currentResonance == null) {
      newResonance = 'hell_yes';
    } else if (currentResonance == 'hell_yes') {
      newResonance = 'meh';
    } else {
      newResonance = '';
    }

    debugPrint('[CoachingHistory] 💚 Resonance toggle initiated');
    debugPrint('[CoachingHistory]    → Document ID: $docId');
    debugPrint('[CoachingHistory]    → Previous: "$currentResonance"');
    debugPrint('[CoachingHistory]    → New: "$newResonance"');

    try {
      // Optimistically update UI
      setState(() {
        coaching['resonance'] = newResonance;
      });

      // Update the existing document in Firebase
      await FirebaseService.updateCoachingResonance(
        docId: docId,
        resonance: newResonance,
      );
      
      debugPrint('[CoachingHistory] ✅ Resonance successfully updated!');
      debugPrint('[CoachingHistory]    → State changed from "$currentResonance" to "$newResonance"');
    } catch (e) {
      debugPrint('[CoachingHistory] ❌ Error updating resonance: $e');
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

  Widget _buildHeartIcon(String? resonance) {
    Widget icon;
    String label;
    
    if (resonance == 'hell_yes') {
      // Red filled heart
      icon = const Icon(
        Icons.favorite,
        color: Colors.red,
        size: 24,
      );
      label = 'Hell Yes!';
    } else if (resonance == 'meh') {
      // Black/blue gradient broken heart
      icon = ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [Colors.black, Colors.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
        child: const Icon(
          Icons.heart_broken,
          color: Colors.white,
          size: 24,
        ),
      );
      label = 'Meh';
    } else {
      // Empty outline heart
      icon = Icon(
        Icons.favorite_border,
        color: Colors.grey.shade400,
        size: 24,
      );
      label = 'No Comment';
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Future<void> _deleteCoaching(Map<String, dynamic> coaching, int index) async {
    final docId = coaching['id'];
    if (docId == null) return;

    debugPrint('[CoachingHistory] 🗑️ Delete requested');
    debugPrint('[CoachingHistory]    → Document ID: $docId');

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Coaching'),
        content: const Text('Are you sure you want to delete this coaching? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      debugPrint('[CoachingHistory] ❌ Deletion cancelled by user');
      return;
    }

    try {
      // Optimistically remove from UI
      setState(() {
        _coachings.removeAt(index);
      });

      // Delete from Firestore
      await FirebaseService.deleteCoaching(docId: docId);
      
      debugPrint('[CoachingHistory] ✅ Coaching successfully deleted!');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Coaching deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('[CoachingHistory] ❌ Error deleting coaching: $e');
      
      // Revert on error - reload list
      _loadCoachings();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting: ${e.toString()}'),
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
    final index = _coachings.indexOf(coaching);

    return Slidable(
      key: ValueKey(coaching['id']),
      // Use platform-specific action pane
      endActionPane: ActionPane(
        motion: Platform.isIOS 
            ? const DrawerMotion() 
            : const ScrollMotion(),
        extentRatio: 0.25, // Only cover 25% of the card width
        children: [
          SlidableAction(
            onPressed: (context) => _deleteCoaching(coaching, index),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            borderRadius: BorderRadius.circular(16),
          ),
        ],
      ),
      child: Card(
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
                    icon: _buildHeartIcon(resonance),
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
      ), // Close Slidable
    );
  }

  void _showCoachingDetail(Map<String, dynamic> coaching) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CoachingFlowScreen(coaching: coaching),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/annoyance_provider.dart';
import '../providers/suggestion_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final annoyanceProvider = Provider.of<AnnoyanceProvider>(context);
    final suggestionProvider = Provider.of<SuggestionProvider>(context);

    final annoyances = annoyanceProvider.annoyances;
    final suggestions = suggestionProvider.suggestions;

    // Calculate metrics
    final annoyanceRate = _calculateAnnoyanceRate(annoyances);
    final followThrough = _calculateFollowThrough(suggestions);
    final hellYesRate = _calculateHellYesRate(suggestions);
    final timeToAction = _calculateTimeToAction(suggestions);
    final topCategory = annoyanceProvider.getTopCategory();
    final distribution = annoyanceProvider.getCategoryDistribution();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: annoyances.length < 3
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'Patterns appear after 3 entries.',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Pattern
                  const Text(
                    'Top Pattern',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (topCategory != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            topCategory,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2D9CDB),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${((distribution[topCategory]! / annoyances.length) * 100).toStringAsFixed(0)}% this week',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Metrics Grid
                  const Text(
                    'Metrics',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          label: 'Annoyance Rate',
                          value: '$annoyanceRate/week',
                          trend: null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          label: 'Time to Action',
                          value: timeToAction,
                          trend: null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricCard(
                          label: 'Follow-Through',
                          value: '$followThrough%',
                          trend: null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricCard(
                          label: 'HELL YES Rate',
                          value: '$hellYesRate%',
                          trend: null,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Category Distribution
                  const Text(
                    'Category Distribution',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...distribution.entries.map((entry) {
                    final percent =
                        ((entry.value / annoyances.length) * 100)
                            .toStringAsFixed(0);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                entry.key,
                                style: const TextStyle(fontSize: 16),
                              ),
                              const Spacer(),
                              Text(
                                '$percent%',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          LinearProgressIndicator(
                            value: entry.value / annoyances.length,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFF2D9CDB),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  const SizedBox(height: 32),

                  // Recent Suggestions
                  if (suggestions.isNotEmpty) ...[
                    const Text(
                      'Recent Suggestions',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...suggestions.take(3).map((suggestion) {
                      final completed = suggestion.completedTimestamp != null;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            suggestion.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            DateFormat('MMM d').format(suggestion.timestamp),
                          ),
                          trailing: completed
                              ? const Icon(Icons.check_circle,
                                  color: Colors.green)
                              : null,
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
    );
  }

  int _calculateAnnoyanceRate(List annoyances) {
    if (annoyances.isEmpty) return 0;
    // Simple calculation: count from last 7 days
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    final recentCount =
        annoyances.where((a) => a.timestamp.isAfter(sevenDaysAgo)).length;
    return recentCount;
  }

  int _calculateFollowThrough(List suggestions) {
    if (suggestions.isEmpty) return 0;
    final completed =
        suggestions.where((s) => s.completedTimestamp != null).length;
    return ((completed / suggestions.length) * 100).round();
  }

  int _calculateHellYesRate(List suggestions) {
    if (suggestions.isEmpty) return 0;
    final hellYes =
        suggestions.where((s) => s.resonance == 'hell_yes').length;
    return ((hellYes / suggestions.length) * 100).round();
  }

  String _calculateTimeToAction(List suggestions) {
    final completed =
        suggestions.where((s) => s.completedTimestamp != null).toList();
    if (completed.isEmpty) return '--';

    // Calculate average time from suggestion to completion
    int totalMinutes = 0;
    for (final s in completed) {
      final duration =
          s.completedTimestamp!.difference(s.timestamp).inMinutes;
      totalMinutes += duration as int;
    }

    final avgMinutes = totalMinutes ~/ completed.length;
    if (avgMinutes < 60) {
      return '${avgMinutes}m';
    } else {
      return '${(avgMinutes / 60).toStringAsFixed(0)}h';
    }
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? trend;

  const _MetricCard({
    required this.label,
    required this.value,
    this.trend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}


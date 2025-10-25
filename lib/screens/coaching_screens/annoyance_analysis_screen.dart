import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/annoyance_provider.dart';
import '../../models/annoyance.dart';

/// Screen 3: Annoyance Analysis with beautiful visualizations
class AnnoyanceAnalysisScreen extends StatefulWidget {
  final String uid;
  final AnnoyanceProvider annoyanceProvider;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;
  
  const AnnoyanceAnalysisScreen({
    super.key,
    required this.uid,
    required this.annoyanceProvider,
    required this.onSwipeLeft,
    required this.onSwipeRight,
  });

  @override
  State<AnnoyanceAnalysisScreen> createState() => _AnnoyanceAnalysisScreenState();
}

class _AnnoyanceAnalysisScreenState extends State<AnnoyanceAnalysisScreen> {
  Map<String, int> _categoryBreakdown = {};
  Map<String, int> _triggerBreakdown = {};
  int _totalAnnoyances = 0;
  int _last7DaysCount = 0;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    await widget.annoyanceProvider.loadAnnoyances(widget.uid);
    
    final annoyances = widget.annoyanceProvider.annoyances;
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    
    // Category breakdown
    Map<String, int> categoryCount = {};
    Map<String, int> triggerCount = {};
    int last7 = 0;
    
    for (var annoyance in annoyances) {
      // Category count
      categoryCount[annoyance.category] = (categoryCount[annoyance.category] ?? 0) + 1;
      
      // Trigger count (top triggers)
      triggerCount[annoyance.trigger] = (triggerCount[annoyance.trigger] ?? 0) + 1;
      
      // Time-based counts
      if (annoyance.timestamp.isAfter(sevenDaysAgo)) {
        last7++;
      }
    }
    
    setState(() {
      _categoryBreakdown = categoryCount;
      _triggerBreakdown = triggerCount;
      _totalAnnoyances = annoyances.length;
      _last7DaysCount = last7;
    });
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case AnnoyanceCategory.boundaries:
        return const Color(0xFFE91E63); // Pink
      case AnnoyanceCategory.environment:
        return const Color(0xFF2196F3); // Blue
      case AnnoyanceCategory.systemsDebt:
        return const Color(0xFF4CAF50); // Green
      case AnnoyanceCategory.communication:
        return const Color(0xFFFF9800); // Orange
      case AnnoyanceCategory.energy:
        return const Color(0xFF9C27B0); // Purple
      default:
        return const Color(0xFF607D8B); // Grey
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF667eea),
            const Color(0xFF764ba2),
          ],
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 60),
                
                // Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: const Text(
                    'ANNOYANCE ANALYSIS',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Stats cards
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total',
                        _totalAnnoyances.toString(),
                        Icons.analytics,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Last 7 Days',
                        _last7DaysCount.toString(),
                        Icons.calendar_today,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                // Category breakdown pie chart
                _buildChartCard(
                  'Category Breakdown',
                  _buildPieChart(),
                  height: 280,
                ),
                
                const SizedBox(height: 24),
                
                // Category legend
                _buildCategoryLegend(),
                
                const SizedBox(height: 32),
                
                // Top triggers
                if (_triggerBreakdown.isNotEmpty)
                  _buildChartCard(
                    'Top Triggers',
                    _buildTopTriggers(),
                    height: 260,
                  ),
                
                const SizedBox(height: 40),
                
                // Swipe hint
                Center(
                  child: GestureDetector(
                    onTap: widget.onSwipeLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Swipe left to continue',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Icon(
                            Icons.arrow_forward,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 28,
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartCard(String title, Widget chart, {double height = 200}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(height: height, child: chart),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    if (_categoryBreakdown.isEmpty) {
      return const Center(
        child: Text(
          'No data yet',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    return PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 60,
        sections: _categoryBreakdown.entries.map((entry) {
          final percentage = (entry.value / _totalAnnoyances * 100).toInt();
          return PieChartSectionData(
            color: _getCategoryColor(entry.key),
            value: entry.value.toDouble(),
            title: '$percentage%',
            radius: 80,
            titleStyle: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoryLegend() {
    if (_categoryBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _categoryBreakdown.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: _getCategoryColor(entry.key),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                Text(
                  '${entry.value} (${(entry.value / _totalAnnoyances * 100).toInt()}%)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTopTriggers() {
    // Get top 5 triggers
    final topTriggers = _triggerBreakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    
    final top5 = topTriggers.take(5).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: top5.asMap().entries.map((entry) {
        final index = entry.key;
        final trigger = entry.value;
        final percentage = (trigger.value / _totalAnnoyances * 100).toInt();
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    '${index + 1}.',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF667eea),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trigger.key.length > 40 ? '${trigger.key.substring(0, 40)}...' : trigger.key,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  Text(
                    '$percentage%',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF667eea),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: percentage / 100,
                backgroundColor: Colors.grey.shade200,
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}


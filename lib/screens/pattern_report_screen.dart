import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/annoyance_provider.dart';
import '../services/analytics_service.dart';

class PatternReportScreen extends StatelessWidget {
  const PatternReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final annoyanceProvider = Provider.of<AnnoyanceProvider>(context);
    final patternReport = annoyanceProvider.getPatternReport();

    if (patternReport == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Pattern Report'),
        ),
        body: const Center(
          child: Text('Patterns appear after 3 entries.'),
        ),
      );
    }

    // Log analytics
    AnalyticsService.logPatternReportShown();

    final topCategory = patternReport['top_category'] as String;
    final percentage = patternReport['percentage'] as String;
    final total = patternReport['total'] as int;
    final distribution = patternReport['distribution'] as Map<String, int>;

    return Scaffold(
      appBar: AppBar(
        title: const Text('First Pattern Report'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Magic moment badge
            Center(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 64,
                  color: Color(0xFF0F766E),
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Your Pattern Emerged',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // Top pattern card
            Container(
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
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$percentage% of $total entries',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Distribution breakdown
            const Text(
              'Category Breakdown',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            ...distribution.entries.map((entry) {
              final count = entry.value;
              final percent = ((count / total) * 100).toStringAsFixed(0);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                    Text(
                      '$count ($percent%)',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: 32),

            // Next step
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'Next Step',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Keep capturing. Your daily coach suggestion will focus on your top patterns.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Got it',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}








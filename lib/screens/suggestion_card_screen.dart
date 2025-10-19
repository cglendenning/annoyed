import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/suggestion.dart';
import '../providers/suggestion_provider.dart';
import '../providers/annoyance_provider.dart';

class SuggestionCardScreen extends StatelessWidget {
  final Suggestion suggestion;

  const SuggestionCardScreen({
    super.key,
    required this.suggestion,
  });

  @override
  Widget build(BuildContext context) {
    final suggestionProvider = Provider.of<SuggestionProvider>(context);
    final annoyanceProvider = Provider.of<AnnoyanceProvider>(context);
    
    final distribution = annoyanceProvider.getCategoryDistribution();
    final total = annoyanceProvider.annoyances.length;
    final categoryPercent = total > 0
        ? ((distribution[suggestion.category] ?? 0) / total * 100)
            .toStringAsFixed(0)
        : '0';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Suggestion'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Suggestion text
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
                    Icon(
                      suggestion.type == 'reframe'
                          ? Icons.psychology_outlined
                          : Icons.track_changes,
                      size: 48,
                      color: const Color(0xFF0F766E),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      suggestion.text,
                      style: const TextStyle(
                        fontSize: 18,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${suggestion.durationDays} days',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F766E),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Resonance
              const Text(
                'Resonance',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: suggestion.resonance != null
                          ? null
                          : () async {
                              await suggestionProvider.setResonance(
                                suggestion,
                                'meh',
                              );
                            },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(
                          color: suggestion.resonance == 'meh'
                              ? Colors.orange
                              : Colors.grey.shade300,
                          width: suggestion.resonance == 'meh' ? 2 : 1,
                        ),
                      ),
                      child: const Text(
                        'Meh',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: suggestion.resonance != null
                          ? null
                          : () async {
                              await suggestionProvider.setResonance(
                                suggestion,
                                'hell_yes',
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: suggestion.resonance == 'hell_yes'
                            ? Colors.green
                            : const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'HELL YES!',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Action
              const Text(
                'Action',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // Snooze functionality - remind user later
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Snoozed for later')),
                        );
                        Navigator.of(context).pop();
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Snoozed for 90 minutes'),
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Snooze 90m',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: suggestion.completedTimestamp != null
                          ? null
                          : () async {
                              await suggestionProvider.markCompleted(suggestion);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('✓ Marked as done!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: suggestion.completedTimestamp != null
                            ? Colors.green
                            : const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        suggestion.completedTimestamp != null
                            ? 'Done!'
                            : 'Did it',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              // Why this?
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F766E).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Color(0xFF0F766E),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                          children: [
                            const TextSpan(text: 'Your top pattern is '),
                            TextSpan(
                              text: '${suggestion.category} ($categoryPercent%)',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const TextSpan(text: ' this week.'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}









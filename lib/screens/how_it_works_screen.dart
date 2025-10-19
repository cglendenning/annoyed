import 'package:flutter/material.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';

class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('How It Works'),
        backgroundColor: AppColors.primaryTeal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            const Text(
              'Understanding Your Journey',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Here\'s how Annoyed transforms your frustrations into growth',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 40),
            
            // Section 1: Categories
            _buildSectionHeader(
              icon: Icons.category,
              title: 'Color-Coded Categories',
              subtitle: 'Every annoyance gets categorized automatically',
            ),
            
            const SizedBox(height: 20),
            
            _buildCategoryItem(
              color: const Color(0xFFE74C3C),
              category: 'Boundaries',
              description: 'Personal limits, saying no, overcommitment, people-pleasing',
            ),
            
            const SizedBox(height: 12),
            
            _buildCategoryItem(
              color: const Color(0xFF3498DB),
              category: 'Environment',
              description: 'Physical space, noise, clutter, distractions, surroundings',
            ),
            
            const SizedBox(height: 12),
            
            _buildCategoryItem(
              color: const Color(0xFFF39C12),
              category: 'Life Systems',
              description: 'Routines, processes, organization, systems that need improvement',
            ),
            
            const SizedBox(height: 12),
            
            _buildCategoryItem(
              color: const Color(0xFF9B59B6),
              category: 'Communication',
              description: 'Expressing yourself, being heard, conversations, clarity',
            ),
            
            const SizedBox(height: 12),
            
            _buildCategoryItem(
              color: const Color(0xFF2ECC71),
              category: 'Energy',
              description: 'Emotional state, motivation, burnout, vitality, enthusiasm',
            ),
            
            const SizedBox(height: 40),
            
            // Section 2: Coaching Structure
            _buildSectionHeader(
              icon: Icons.auto_awesome,
              title: 'Two-Part Coaching',
              subtitle: 'Every coaching includes both mindset and action',
            ),
            
            const SizedBox(height: 20),
            
            _buildCoachingComponent(
              gradient: [Colors.white, const Color(0xFFFFF5F5)],
              icon: Icons.psychology,
              title: 'MINDSET SHIFT',
              description: 'A new way of thinking about your pattern. This reframes your perspective and helps you see the situation differently.',
              examples: [
                'Why you\'re perceiving things this way',
                'The hidden beliefs driving your reaction',
                'A more empowering mental frame',
              ],
            ),
            
            const SizedBox(height: 20),
            
            _buildCoachingComponent(
              gradient: [const Color(0xFFFFF5F5), Colors.white],
              icon: Icons.bolt,
              title: 'ACTION STEP',
              description: 'A concrete behavior change to implement. This is the practical step that creates real transformation.',
              examples: [
                'Specific actions you can take today',
                'New habits to practice',
                'Communication techniques to try',
              ],
            ),
            
            const SizedBox(height: 40),
            
            // Section 3: The Process
            _buildSectionHeader(
              icon: Icons.timeline,
              title: 'The Transformation Process',
              subtitle: 'How your annoyances become breakthroughs',
            ),
            
            const SizedBox(height: 20),
            
            _buildProcessStep(
              number: '1',
              title: 'Capture',
              description: 'Record what annoys you as it happens. Raw, unfiltered, authentic.',
              color: AppColors.primaryTeal,
            ),
            
            const SizedBox(height: 16),
            
            _buildProcessStep(
              number: '2',
              title: 'Pattern Detection',
              description: 'After ${AppConstants.annoyancesPerCoaching} entries, AI analyzes your patterns and identifies themes.',
              color: AppColors.primaryTeal,
            ),
            
            const SizedBox(height: 16),
            
            _buildProcessStep(
              number: '3',
              title: 'Coaching',
              description: 'Get personalized insights with both a mindset shift AND an action step.',
              color: AppColors.accentCoral,
            ),
            
            const SizedBox(height: 16),
            
            _buildProcessStep(
              number: '4',
              title: 'Transform',
              description: 'Apply the coaching. Make the change. Feel the difference in your life.',
              color: AppColors.accentCoral,
            ),
            
            const SizedBox(height: 40),
            
            // Privacy callout
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryTealLight.withOpacity(0.1),
                    AppColors.accentCoralLight.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primaryTeal.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primaryTeal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      color: AppColors.primaryTeal,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your Privacy Matters',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Audio never leaves your phone. Only redacted text is sent for AI coaching.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.black54,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.primaryTeal, AppColors.accentCoral],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryTeal.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 15,
            color: Colors.grey.shade600,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
  
  Widget _buildCategoryItem({
    required Color color,
    required String category,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category chip matching the History screen style
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              category,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCoachingComponent({
    required List<Color> gradient,
    required IconData icon,
    required String title,
    required String description,
    required List<String> examples,
  }) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradient,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryTeal, AppColors.accentCoral],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  color: Color(0xFF0F766E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Includes:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          ...examples.map((example) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '• ',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.primaryTeal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: Text(
                    example,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
  
  Widget _buildProcessStep({
    required String number,
    required String title,
    required String description,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 10,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}


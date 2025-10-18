import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_colors.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About Coach Craig'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Coach Craig photo
            Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.primaryTeal,
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0x4D0F766E),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/coach_craig.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: AppColors.primaryTealLight,
                      child: const Icon(
                        Icons.person,
                        size: 100,
                        color: Colors.white,
                      ),
                    );
                  },
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Name
            const Text(
              'Coach Craig',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Your Personal Growth Guide',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Bio
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primaryTealLight.withAlpha(26),
                    AppColors.accentCoralLight.withAlpha(26),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Hi! I\'m Coach Craig, and I\'m passionate about helping people transform their daily frustrations into actionable insights. '
                'Through the Annoyed app, I combine behavioral psychology with practical coaching to help you identify patterns in what bothers you '
                'and give you specific, achievable changes you can make today.\n\n'
                'My approach is simple: awareness leads to understanding, and understanding leads to change. '
                'Let\'s work together to turn your annoyances into opportunities for growth.',
                style: TextStyle(
                  fontSize: 16,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Links section
            const Text(
              'Connect & Explore',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Still Waters Retreats
            _buildLinkButton(
              context: context,
              icon: Icons.spa_outlined,
              title: 'Still Waters Retreats',
              subtitle: 'Mindful retreats & coaching',
              color: const Color(0xFF4A90A4),
              onTap: () => _launchURL('https://www.stillwatersretreats.com'),
            ),
            
            const SizedBox(height: 12),
            
            // YouTube button
            _buildLinkButton(
              context: context,
              icon: Icons.play_circle_outline,
              title: 'YouTube Channel',
              subtitle: 'Green Pyramid - Personal growth content',
              color: const Color(0xFFFF0000),
              onTap: () => _launchURL('https://www.youtube.com/@GreenPyramid-mk5xp'),
            ),
            
            const SizedBox(height: 12),
            
            // Green Pyramid App - Platform-specific
            if (Platform.isIOS)
              _buildLinkButton(
                context: context,
                icon: Icons.apple,
                title: 'Green Pyramid App',
                subtitle: 'Available on the App Store',
                color: AppColors.primaryTeal,
                onTap: () => _launchURL('https://apps.apple.com/us/app/green-pyramid-your-best-life/id6450578276'),
              ),
            
            if (Platform.isAndroid) ...[
              const SizedBox(height: 12),
              _buildLinkButton(
                context: context,
                icon: Icons.android,
                title: 'Green Pyramid App',
                subtitle: 'Available on Google Play',
                color: const Color(0xFF3DDC84),
                onTap: () => _launchURL('https://play.google.com/store/apps/details?id=com.cglendenning.life_ops&hl=en_US'),
              ),
            ],
            
            const SizedBox(height: 32),
            
            // Footer
            Text(
              'Made with ❤️ by Coach Craig',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
            
            const SizedBox(height: 8),
            
            Text(
              '© ${DateTime.now().year} Annoyed App',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLinkButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withAlpha(26),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


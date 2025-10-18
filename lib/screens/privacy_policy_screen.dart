import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Last Updated: October 18, 2025',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 24),
            
            _SectionTitle('1. Introduction'),
            _SectionText(
              'Coach Craig and the Annoyed app ("we", "us", "our") are committed to protecting your privacy. '
              'This Privacy Policy explains how we collect, use, disclose, and safeguard your information in compliance with '
              'U.S. privacy laws including COPPA, CCPA, and the European Union\'s General Data Protection Regulation (GDPR).'
            ),
            
            _SectionTitle('2. Information We Collect'),
            _SectionText(
              'Personal Information:\n'
              '• Email address (required for account creation)\n'
              '• Password (encrypted and never stored in plain text)\n'
              '• Marketing preferences (if you opt-in)\n\n'
              'Usage Data:\n'
              '• Voice recordings and text entries of annoyances\n'
              '• App usage analytics and patterns\n'
              '• Device information and IP address\n'
              '• Coaching interactions and feedback'
            ),
            
            _SectionTitle('3. How We Use Your Information'),
            _SectionText(
              'We use your information to:\n'
              '• Provide personalized coaching and insights\n'
              '• Analyze patterns in your recorded annoyances\n'
              '• Improve our AI recommendations\n'
              '• Send you service updates and notifications\n'
              '• Send marketing communications (only if you opt-in)\n'
              '• Comply with legal obligations'
            ),
            
            _SectionTitle('4. Legal Basis for Processing (GDPR)'),
            _SectionText(
              'We process your data based on:\n'
              '• Your consent (for marketing emails)\n'
              '• Contract performance (to provide the Service)\n'
              '• Legitimate interests (to improve the Service)\n'
              '• Legal obligations (to comply with laws)'
            ),
            
            _SectionTitle('5. Data Storage and Security'),
            _SectionText(
              'Your data is stored securely in Google Firebase, which complies with SOC 2, ISO 27001, and GDPR requirements. '
              'We use industry-standard encryption for data in transit and at rest. Your password is hashed using bcrypt and never stored in plain text.\n\n'
              'Data is stored in Firebase servers located in the United States. By using the Service, you consent to this transfer if you are located outside the U.S.'
            ),
            
            _SectionTitle('6. Data Sharing'),
            _SectionText(
              'We do NOT sell your personal information to third parties.\n\n'
              'We may share data with:\n'
              '• OpenAI (for AI coaching generation - anonymized where possible)\n'
              '• Firebase/Google Cloud (for data storage and processing)\n'
              '• RevenueCat (for subscription management)\n'
              '• Law enforcement (if required by law)'
            ),
            
            _SectionTitle('7. Your Rights'),
            _SectionText(
              'Under GDPR and CCPA, you have the right to:\n'
              '• Access your personal data\n'
              '• Correct inaccurate data\n'
              '• Delete your data ("right to be forgotten")\n'
              '• Export your data (data portability)\n'
              '• Opt-out of marketing communications\n'
              '• Withdraw consent at any time\n\n'
              'To exercise these rights, go to Settings > Privacy or contact us directly.'
            ),
            
            _SectionTitle('8. Marketing Communications'),
            _SectionText(
              'If you opt-in to receive coaching tips and deals from Coach Craig, we will send you:\n'
              '• Weekly coaching insights\n'
              '• Exclusive offers and discounts\n'
              '• Updates about new features\n\n'
              'You can unsubscribe at any time by clicking "unsubscribe" in any email or updating your preferences in Settings.'
            ),
            
            _SectionTitle('9. Data Retention'),
            _SectionText(
              'We retain your data for as long as your account is active. '
              'If you delete your account, all personal data will be permanently deleted within 30 days, except where required by law.'
            ),
            
            _SectionTitle('10. Children\'s Privacy'),
            _SectionText(
              'The Service is not intended for children under 13 (or 16 in the EU). '
              'We do not knowingly collect data from children. If we learn we have collected data from a child, we will delete it immediately.'
            ),
            
            _SectionTitle('11. International Users'),
            _SectionText(
              'If you are accessing the Service from outside the United States, please note that your data will be transferred to and processed in the U.S. '
              'By using the Service, you consent to this transfer.'
            ),
            
            _SectionTitle('12. Changes to Privacy Policy'),
            _SectionText(
              'We may update this Privacy Policy from time to time. We will notify you of material changes via email or in-app notification. '
              'Continued use of the Service after changes constitutes acceptance.'
            ),
            
            _SectionTitle('13. Contact Us'),
            _SectionText(
              'For privacy questions or to exercise your rights, contact us:\n'
              '• Through the app\'s Settings > Privacy\n'
              '• Via YouTube: youtube.com/@GreenPyramid-mk5xp'
            ),
            
            _SectionTitle('14. Data Protection Officer'),
            _SectionText(
              'For GDPR-related inquiries, you may contact our Data Protection Officer through the app support feature.'
            ),
            
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  
  const _SectionTitle(this.title);
  
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _SectionText extends StatelessWidget {
  final String text;
  
  const _SectionText(this.text);
  
  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 15,
        height: 1.5,
      ),
    );
  }
}


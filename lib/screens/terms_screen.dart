import 'package:flutter/material.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Terms of Service',
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
            
            _SectionTitle('1. Acceptance of Terms'),
            _SectionText(
              'By creating an account and using the Annoyed app ("Service"), you agree to be bound by these Terms of Service. '
              'If you do not agree to these terms, please do not use the Service.'
            ),
            
            _SectionTitle('2. Account Registration'),
            _SectionText(
              'You must provide a valid email address and create a secure password to use the Service. '
              'You are responsible for maintaining the confidentiality of your account credentials and for all activities under your account.'
            ),
            
            _SectionTitle('3. Data Collection and Privacy'),
            _SectionText(
              'We collect and store your email address, the content you record (annoyances), and usage data to provide and improve the Service. '
              'We are committed to protecting your privacy and comply with applicable U.S. laws and the General Data Protection Regulation (GDPR).\n\n'
              'Your data is stored securely in Firebase and is never sold to third parties. See our Privacy Policy for detailed information.'
            ),
            
            _SectionTitle('4. User Content'),
            _SectionText(
              'You retain ownership of the content you create (voice recordings, text entries). '
              'By using the Service, you grant us a license to process this content to provide personalized coaching and insights. '
              'You may delete your content at any time from within the app.'
            ),
            
            _SectionTitle('5. Acceptable Use'),
            _SectionText(
              'You agree not to:\n'
              '• Use the Service for any illegal purpose\n'
              '• Share your account with others\n'
              '• Attempt to gain unauthorized access to the Service\n'
              '• Upload malicious content or spam'
            ),
            
            _SectionTitle('6. AI-Generated Content'),
            _SectionText(
              'The coaching recommendations provided by the Service are generated using artificial intelligence. '
              'While we strive for accuracy and helpfulness, these recommendations are for informational purposes only and do not constitute professional medical, psychological, or legal advice.'
            ),
            
            _SectionTitle('7. Subscription and Payments'),
            _SectionText(
              'Some features may require a paid subscription. Subscription fees are processed through Apple App Store or Google Play Store. '
              'Refunds are subject to the policies of these platforms.'
            ),
            
            _SectionTitle('8. Data Retention and Deletion'),
            _SectionText(
              'You have the right to request deletion of your data at any time. '
              'You can delete your account from the Settings screen. Upon deletion, all your personal data will be permanently removed within 30 days.'
            ),
            
            _SectionTitle('9. Changes to Terms'),
            _SectionText(
              'We may update these Terms of Service from time to time. We will notify you of significant changes via email or in-app notification.'
            ),
            
            _SectionTitle('10. Limitation of Liability'),
            _SectionText(
              'The Service is provided "as is" without warranties of any kind. '
              'Coach Craig and Annoyed app shall not be liable for any indirect, incidental, or consequential damages arising from your use of the Service.'
            ),
            
            _SectionTitle('11. Governing Law'),
            _SectionText(
              'These Terms are governed by the laws of the United States. Any disputes will be resolved in accordance with U.S. law.'
            ),
            
            _SectionTitle('12. Contact'),
            _SectionText(
              'For questions about these Terms, please contact us through the app\'s support feature or visit our YouTube channel at youtube.com/@GreenPyramid-mk5xp'
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


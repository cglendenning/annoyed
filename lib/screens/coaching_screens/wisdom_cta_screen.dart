import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/background_images.dart';

/// Screen 4: Wisdom & Call-to-Action for 1:1 coaching
class WisdomCtaScreen extends StatefulWidget {
  final VoidCallback onSwipeRight;
  
  const WisdomCtaScreen({
    super.key,
    required this.onSwipeRight,
  });

  @override
  State<WisdomCtaScreen> createState() => _WisdomCtaScreenState();
}

class _WisdomCtaScreenState extends State<WisdomCtaScreen> {
  String? _backgroundImage;
  String _wisdomQuote = '';
  
  // Collection of wisdom quotes with spiritual depth
  final List<String> _wisdomQuotes = [
    'The systems you built to free you have become your cage. It\'s time to remember who you were before the machine.',
    'You created the blueprint. Now the blueprint controls you. Freedom begins when you step outside the architecture.',
    'The entrepreneur\'s paradox: You built it all to gain time, but now time owns you. Reclaim your sovereignty.',
    'Every system you built was once a solution. Today, they\'re the problem. Evolution demands letting go.',
    'You are not your business. You are not your systems. You are the space between—the observer, the creator.',
    'The cage you live in is made of your own design. The key has always been in your hand.',
    'Mastery isn\'t building more. It\'s knowing when to tear down what no longer serves your highest self.',
    'You automated everything but your soul. Return to what matters.',
    'The patterns that built your empire are now your prison. Break the pattern, free the builder.',
    'True freedom is realizing the systems serve you—not the other way around.',
  ];

  @override
  void initState() {
    super.initState();
    _selectRandomBackground();
    _selectRandomWisdom();
  }
  
  void _selectRandomBackground() {
    final random = Random();
    setState(() {
      _backgroundImage = backgroundImages[random.nextInt(backgroundImages.length)];
    });
  }
  
  void _selectRandomWisdom() {
    final random = Random();
    setState(() {
      _wisdomQuote = _wisdomQuotes[random.nextInt(_wisdomQuotes.length)];
    });
  }

  Future<void> _openCalendly() async {
    // Calendly link for 15-minute 1:1 coaching session
    final uri = Uri.parse('https://calendly.com/c_glendenning/15min');
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open scheduling page'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background image
        if (_backgroundImage != null)
          Positioned.fill(
            child: Image.asset(
              _backgroundImage!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFF0F766E),
                        Color(0xFF134E4A),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        
        // Dark overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.4),
                  Colors.black.withValues(alpha: 0.7),
                ],
              ),
            ),
          ),
        ),
        
        // Content
        SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 80),
                  
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.3),
                          blurRadius: 50,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      size: 64,
                      color: Colors.white,
                    ),
                  ),
                  
                  const SizedBox(height: 48),
                  
                  // Wisdom quote
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      _wisdomQuote,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                        letterSpacing: 0.3,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  
                  const SizedBox(height: 64),
                  
                  // Divider
                  Container(
                    width: 60,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  const SizedBox(height: 64),
                  
                  // CTA Section
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Coach profile image
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFF0F766E),
                              width: 3,
                            ),
                            image: const DecorationImage(
                              image: AssetImage('assets/images/coach_craig.jpg'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        const Text(
                          'Ready for the Next Level?',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1E293B),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 16),
                        
                        Text(
                          'I specialize in helping "Boxed-in Builders" who have become entrapped by the systems they created to run their businesses.',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade700,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 24),
                        
                        Text(
                          'Let\'s see if we\'re a fit.',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // CTA Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _openCalendly,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F766E),
                              foregroundColor: Colors.white,
                              elevation: 8,
                              shadowColor: const Color(0xFF0F766E).withValues(alpha: 0.5),
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.calendar_month,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Schedule 15-Min Discovery Call',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        Text(
                          'No strings attached. Just a conversation.',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}


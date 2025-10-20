import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../providers/auth_state_manager.dart';
import '../services/analytics_service.dart';
import '../utils/app_colors.dart';
import '../widgets/animated_gradient_container.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  
  const OnboardingScreen({super.key, this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _hasRequestedSpeechPermission = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            PageView(
          controller: _pageController,
          onPageChanged: (page) {
            setState(() {
                  _currentPage = page;
            });
          },
              children: [
                const _IntroPage(),
                const _TutorialPage(),
                const _HowItWorksPage(),
                _SpeechRecognitionPermissionPage(
                  onPermissionGranted: () async {
                    if (!_hasRequestedSpeechPermission) {
                      _hasRequestedSpeechPermission = true;
                      await _requestSpeechPermission();
                    }
                  },
                  onSwipeToComplete: () {
                    // Trigger navigation when user swipes right
                    if (_hasRequestedSpeechPermission) {
                      _completeOnboarding();
                    }
                  },
                ),
              ],
            ),
            
            // Page indicators
            if (_currentPage < 4)
              Positioned(
                bottom: 80,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == index
                            ? const Color(0xFF0F766E)
                            : Colors.grey.shade300,
                      ),
                    );
                  }),
                ),
              ),
              
            // Swipe hint
            if (_currentPage < 4)
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Swipe to continue',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestSpeechPermission() async {
    await Future.delayed(const Duration(milliseconds: 500));
    final speech = stt.SpeechToText();
    final available = await speech.initialize(
      onError: (error) => debugPrint('Speech error: ${error.errorMsg}'),
      onStatus: (status) => debugPrint('Speech status: $status'),
    );

    if (available) {
      await AnalyticsService.logPermissionMicGranted();
    }

    // Complete onboarding - AuthStateManager will handle anonymous sign-in
    await _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    if (mounted) {
      final authStateManager = Provider.of<AuthStateManager>(context, listen: false);
      try {
        // This will save the flag AND sign in anonymously
        await authStateManager.completeOnboarding();
        
        // Notify parent (optional, state change will trigger UI update anyway)
        widget.onComplete?.call();
      } catch (e) {
        debugPrint('Error completing onboarding: $e');
      }
    }
  }
}

class _IntroPage extends StatelessWidget {
  const _IntroPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          ClipOval(
            child: AnimatedGradientContainer(
              colors: const [
                AppColors.primaryTealLight,
                AppColors.primaryTeal,
                AppColors.accentCoralLight,
              ],
              duration: const Duration(seconds: 4),
              child: Container(
                padding: const EdgeInsets.all(20),
                child: const Icon(
                  Icons.bolt_outlined,
                  size: 60,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          ShaderMask(
            shaderCallback: (bounds) => AppColors.meshGradient.createShader(bounds),
            child: const Text(
              'Annoyed',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                letterSpacing: -1,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Turn your annoyances into action',
            style: TextStyle(
              fontSize: 18,
              color: Colors.black54,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          Container(
            padding: const EdgeInsets.all(24),
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
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.mic, color: AppColors.primaryTeal),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Record what annoys you',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: AppColors.primaryTeal),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Get personalized coaching',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.psychology, color: AppColors.accentCoral),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Make one key change',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          
          // Sketched arrow indicating swipe right
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Swipe to continue',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              CustomPaint(
                size: const Size(40, 20),
                painter: _SketchedArrowPainter(),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Your data stays private and secure',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black38,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
}

class _TutorialPage extends StatefulWidget {
  const _TutorialPage();

  @override
  State<_TutorialPage> createState() => _TutorialPageState();
}

class _TutorialPageState extends State<_TutorialPage> {
  String _displayedText = '';
  final String _fullText = "My coworker keeps interrupting me in meetings";
  Timer? _textTimer;
  int _textIndex = 0;

  bool _showRecordingBox = false;

  @override
  void initState() {
    super.initState();
    // Start the tutorial sequence
    _startTutorial();
  }

  void _startTutorial() async {
    // Start with recording box showing
    if (mounted) {
      setState(() {
        _showRecordingBox = true;
      });
      
      // Start typing text immediately
      _startTypingAnimation();
    }
  }

  void _startTypingAnimation() {
    _textTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      if (_textIndex < _fullText.length) {
        setState(() {
          _displayedText += _fullText[_textIndex];
          _textIndex++;
        });
      } else {
        timer.cancel();
        // Wait a bit then restart the sequence
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (mounted) {
            _restartAnimation();
          }
        });
      }
    });
  }

  void _restartAnimation() {
    setState(() {
      _showRecordingBox = false;
      _displayedText = '';
      _textIndex = 0;
    });
    _textTimer?.cancel();
    _startTutorial();
  }

  @override
  void dispose() {
    _textTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),

          // Instructions
          const Text(
            'Capture what annoys you',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Tap to start recording, then vent about what\'s bothering you',
            style: TextStyle(
              color: Colors.black54,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 60),

          // Mock record button with animation
          Stack(
            alignment: Alignment.center,
            children: [
              // Recording box (always showing)
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.fiber_manual_record,
                        size: 40,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Recording...',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: SingleChildScrollView(
                          child: Text(
                            _displayedText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              height: 1.5,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const Spacer(),
          const SizedBox(height: 100), // Space for swipe hint
        ],
      ),
    );
  }
}

class _HowItWorksPage extends StatelessWidget {
  const _HowItWorksPage();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          const Text(
            'How It Works',
            style: TextStyle(
              color: Colors.black87,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          
          // Quick overview
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryTealLight.withOpacity(0.2),
                  AppColors.accentCoralLight.withOpacity(0.2),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildQuickPoint(
                  icon: Icons.mic,
                  title: 'Record',
                  description: 'Tap to capture annoyances',
                  color: AppColors.primaryTeal,
                ),
                const SizedBox(height: 16),
                _buildQuickPoint(
                  icon: Icons.category,
                  title: 'Categorize',
                  description: 'Auto-sorted into 5 categories',
                  color: const Color(0xFF3498DB),
                ),
                const SizedBox(height: 16),
                _buildQuickPoint(
                  icon: Icons.auto_awesome,
                  title: 'Get Coaching',
                  description: 'Mindset shift + Action step',
                  color: AppColors.accentCoral,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primaryTeal.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppColors.primaryTeal,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tap "How It Works" in Settings anytime for the full guide',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const Spacer(),
          const SizedBox(height: 100), // Space for swipe hint
        ],
      ),
    );
  }
  
  Widget _buildQuickPoint({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SpeechRecognitionPermissionPage extends StatefulWidget {
  final Future<void> Function() onPermissionGranted;
  final VoidCallback onSwipeToComplete;

  const _SpeechRecognitionPermissionPage({
    required this.onPermissionGranted,
    required this.onSwipeToComplete,
  });

  @override
  State<_SpeechRecognitionPermissionPage> createState() => _SpeechRecognitionPermissionPageState();
}

class _SpeechRecognitionPermissionPageState extends State<_SpeechRecognitionPermissionPage> {
  bool _hasRequested = false;
  bool _isRequesting = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _status = 'Tap button below to grant permissions';
  }

  Future<void> _handleRequest() async {
    if (_isRequesting) return;

    setState(() {
      _isRequesting = true;
    });

    await widget.onPermissionGranted();
    
    if (mounted) {
      setState(() {
        _hasRequested = true;
        _isRequesting = false;
        _status = 'Setup complete! Swipe right to begin →';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragEnd: (details) {
        // If swiping right (positive velocity) and permissions are complete
        if (_hasRequested && details.primaryVelocity != null && details.primaryVelocity! > 0) {
          widget.onSwipeToComplete();
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            const Text(
              'Permissions',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            _status ?? 'Loading...',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const Text(
            'You\'ll see TWO system prompts:',
            style: TextStyle(
              fontSize: 15,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          
          // First dialog mockup
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '1.',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF007AFF),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Speech Recognition',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'To convert speech to text on-device',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Second dialog mockup
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '2.',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF007AFF),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Microphone Access',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'To record your voice',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          const Text(
            'Both happen entirely on your device.\nYour audio never leaves your phone.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          
          // Action button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isRequesting ? null : (_hasRequested ? null : _handleRequest),
              style: ElevatedButton.styleFrom(
                backgroundColor: _hasRequested ? Colors.green : const Color(0xFF0F766E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isRequesting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _hasRequested ? 'Setup Complete ✓' : 'Allow Permissions',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 100), // Space for swipe hint
        ],
      ),
    ),
    );
  }
}

// Custom painter for sketched arrow
class _SketchedArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    
    // Main arrow line (slightly wavy for hand-drawn effect)
    path.moveTo(0, size.height / 2);
    path.cubicTo(
      size.width * 0.3, size.height / 2 - 2,
      size.width * 0.5, size.height / 2 + 2,
      size.width * 0.85, size.height / 2,
    );
    
    // Arrow head top line
    path.moveTo(size.width * 0.85, size.height / 2);
    path.lineTo(size.width * 0.7, size.height * 0.15);
    
    // Arrow head bottom line
    path.moveTo(size.width * 0.85, size.height / 2);
    path.lineTo(size.width * 0.7, size.height * 0.85);
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

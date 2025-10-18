import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../providers/auth_provider.dart';
import '../services/analytics_service.dart';

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
  bool _hasRequestedMicPermission = false;

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
                const _WelcomePage(),
                const _TutorialPage(),
                _SpeechRecognitionPermissionPage(
                  onPermissionGranted: () async {
                    if (!_hasRequestedSpeechPermission) {
                      _hasRequestedSpeechPermission = true;
                      await _requestSpeechPermission();
                      // Onboarding complete - _requestSpeechPermission calls _completeOnboarding
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
            if (_currentPage < 3)
              Positioned(
                bottom: 80,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == index
                            ? const Color(0xFF2D9CDB)
                            : Colors.grey.shade300,
                      ),
                    );
                  }),
                ),
              ),
              
            // Swipe hint
            if (_currentPage < 3)
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
      onError: (error) => print('Speech error: ${error.errorMsg}'),
      onStatus: (status) => print('Speech status: $status'),
    );

    if (available) {
      await AnalyticsService.logPermissionMicGranted();
    }

    // Mark onboarding as complete (this is the last step)
    await _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    
    // Notify parent to re-check onboarding status
    widget.onComplete?.call();
  }
}

class _WelcomePage extends StatefulWidget {
  const _WelcomePage();

  @override
  State<_WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<_WelcomePage> {
  bool _isLoading = false;

  Future<void> _handleAppleSignIn() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.signInWithApple();
      // AuthGate will handle navigation after sign in
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign in failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          const Icon(
            Icons.bolt_outlined,
            size: 80,
            color: Color(0xFF2D9CDB),
          ),
          const SizedBox(height: 24),
          const Text(
            'Annoyed',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              letterSpacing: -1,
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
            child: const Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.mic, color: Color(0xFF2D9CDB)),
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
                    Icon(Icons.lightbulb_outline, color: Color(0xFF2D9CDB)),
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
                    Icon(Icons.psychology, color: Color(0xFF2D9CDB)),
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
          if (_isLoading)
            const CircularProgressIndicator()
          else
            SignInWithAppleButton(
              onPressed: _handleAppleSignIn,
              style: SignInWithAppleButtonStyle.black,
            height: 56,
            ),
          const SizedBox(height: 16),
          const Text(
            'Your data stays private and secure',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black38,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 100), // Space for swipe hint
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
        // If swiping left (negative velocity) and permissions are complete
        if (_hasRequested && details.primaryVelocity != null && details.primaryVelocity! < 0) {
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
                backgroundColor: _hasRequested ? Colors.green : const Color(0xFF2D9CDB),
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

class _MicrophonePermissionPage extends StatefulWidget {
  final Future<void> Function() onPermissionGranted;

  const _MicrophonePermissionPage({
    required this.onPermissionGranted,
  });

  @override
  State<_MicrophonePermissionPage> createState() => _MicrophonePermissionPageState();
}

class _MicrophonePermissionPageState extends State<_MicrophonePermissionPage> {
  bool _hasRequested = false;
  bool _isRequesting = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.microphone.status;
    if (mounted) {
      setState(() {
        if (status.isGranted) {
          _status = 'Permission already granted! Swipe to continue →';
          _hasRequested = true;
        } else if (status.isPermanentlyDenied) {
          _status = 'Permission blocked. Tap button to open Settings';
        } else {
          _status = 'Tap button to request permission';
        }
      });
    }
  }

  Future<void> _handleRequest() async {
    if (_isRequesting) return;

    // Check if permanently denied - if so, open settings
    final currentStatus = await Permission.microphone.status;
    if (currentStatus.isPermanentlyDenied) {
      await openAppSettings();
      return;
    }

    setState(() {
      _isRequesting = true;
    });

    await widget.onPermissionGranted();

    // Check status after request
    final status = await Permission.microphone.status;
    
    if (mounted) {
      setState(() {
        _isRequesting = false;
        if (status.isGranted) {
          _status = 'Permission granted! Swipe to continue →';
          _hasRequested = true;
        } else if (status.isPermanentlyDenied) {
          _status = 'Permission blocked. Tap button to open Settings';
          _hasRequested = false; // Keep button visible
        } else {
          _status = 'Permission denied. Swipe to continue →';
          _hasRequested = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          const Text(
            'Microphone Permission',
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
          const SizedBox(height: 32),
          
          // iOS Permission Dialog Mockup
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.mic,
                  size: 48,
                  color: Color(0xFF007AFF),
                ),
                const SizedBox(height: 16),
                const Text(
                  '"Annoyed" Would Like to\nAccess the Microphone',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'This lets the app record audio for voice input.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                Container(
                  height: 1,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Don\'t Allow',
                        style: TextStyle(
                          fontSize: 17,
                          color: const Color(0xFF007AFF),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 40,
                      color: Colors.grey.shade300,
                    ),
                    const Expanded(
                      child: Text(
                        'OK',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF007AFF),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          const Text(
            'Your audio recordings are only used for on-device\nspeech-to-text conversion.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.black54,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          
          // Action button
          if (!_hasRequested)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
                onPressed: _isRequesting ? null : _handleRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D9CDB),
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
                    : FutureBuilder<PermissionStatus>(
                        future: Permission.microphone.status,
                        builder: (context, snapshot) {
                          final isPermanentlyDenied = snapshot.data?.isPermanentlyDenied ?? false;
                          return Text(
                            isPermanentlyDenied ? 'Open Settings' : 'Allow Microphone',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                          );
                        },
                      ),
              ),
            ),
          const SizedBox(height: 100), // Space for swipe hint
        ],
      ),
    );
  }
}

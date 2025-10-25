import 'dart:convert';
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_state_manager.dart';
import '../../services/paywall_service.dart';
import '../paywall_screen.dart';

/// Screen 2: Deep Dive (Action Step) with text-to-speech and floating play button
class DeepDiveScreen extends StatefulWidget {
  final Map<String, dynamic> coaching;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;
  
  const DeepDiveScreen({
    super.key,
    required this.coaching,
    required this.onSwipeLeft,
    required this.onSwipeRight,
  });

  @override
  State<DeepDiveScreen> createState() => _DeepDiveScreenState();
}

class _DeepDiveScreenState extends State<DeepDiveScreen> {
  final ScrollController _scrollController = ScrollController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  double _loadingProgress = 0.0;
  String? _currentAudioBase64;
  String _selectedVoice = 'nova';
  Timer? _progressTimer;

  @override
  void initState() {
    super.initState();
    _loadVoicePreference();
    // Listen for audio completion
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    });
  }
  
  Future<void> _loadVoicePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedVoice = prefs.getString('tts_voice') ?? 'nova';
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _scrollController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _toggleSpeech() async {
    if (_isPlaying) {
      await _stopSpeaking();
    } else {
      await _startSpeaking();
    }
  }

  Future<void> _startSpeaking() async {
    try {
      final explanation = widget.coaching['explanation'] ?? '';
      
      if (explanation.isEmpty) {
        debugPrint('[DeepDive] No text to speak');
        return;
      }
      
      // If we already have the audio data, just play it
      if (_currentAudioBase64 != null) {
        await _audioPlayer.play(BytesSource(
          _base64ToBytes(_currentAudioBase64!),
          mimeType: 'audio/mpeg',
        ));
        if (mounted) {
          setState(() {
            _isPlaying = true;
          });
        }
        return;
      }
      
      // Start loading with progress
      setState(() {
        _isLoading = true;
        _loadingProgress = 0.0;
      });
      
      final startTime = DateTime.now();
      
      // More realistic estimation based on actual OpenAI TTS performance:
      // - Generation: ~2-3 seconds per 1000 characters
      // - Network overhead: ~500ms base + transfer time
      // - Base64 encoding: minimal overhead
      final charCount = explanation.length;
      final estimatedGenerationTime = (charCount / 1000 * 2500).toInt(); // 2.5s per 1000 chars
      final estimatedNetworkTime = 500 + (charCount / 100).toInt(); // 500ms base + transfer
      final estimatedTotalTime = estimatedGenerationTime + estimatedNetworkTime;
      
      debugPrint('[DeepDive] Estimated total time: ${estimatedTotalTime}ms for $charCount chars');
      
      // Use adaptive progress that accounts for different phases
      _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (!mounted || !_isLoading) {
          timer.cancel();
          return;
        }
        
        final elapsed = DateTime.now().difference(startTime).inMilliseconds;
        
        // Calculate progress with realistic curve:
        // - 0-70%: Generation phase (slower, most of the time)
        // - 70-95%: Network transfer (faster)
        // - 95-100%: Reserved for completion
        double progress;
        final generationPhase = estimatedGenerationTime * 0.7;
        
        if (elapsed < generationPhase) {
          // Generation phase: 0 -> 70%
          progress = (elapsed / generationPhase) * 0.7;
        } else if (elapsed < estimatedTotalTime) {
          // Transfer phase: 70% -> 95%
          final transferElapsed = elapsed - generationPhase;
          final transferTotal = estimatedTotalTime - generationPhase;
          progress = 0.7 + ((transferElapsed / transferTotal) * 0.25);
        } else {
          // Waiting phase: cap at 95%
          progress = 0.95;
        }
        
        setState(() {
          _loadingProgress = progress.clamp(0.0, 0.95);
        });
      });
      
      // Generate TTS audio via Cloud Function
      try {
        debugPrint('[DeepDive] Calling generateTTS with $charCount chars, voice: $_selectedVoice');
        
        final callStartTime = DateTime.now();
        final result = await FirebaseFunctions.instance
            .httpsCallable('generateTTS')
            .call({
              'text': explanation,
              'voice': _selectedVoice,
            });
        
        final actualDuration = DateTime.now().difference(callStartTime).inMilliseconds;
        debugPrint('[DeepDive] Actual generation time: ${actualDuration}ms (estimated: ${estimatedTotalTime}ms)');
        
        // Stop progress timer
        _progressTimer?.cancel();
        
        final audioBase64 = result.data['audioBase64'] as String;
        final voice = result.data['voice'] as String? ?? _selectedVoice;
        debugPrint('[DeepDive] Got audio data: ${audioBase64.length} chars, voice: $voice');
        
        _currentAudioBase64 = audioBase64;
        
        // Show completion
        if (mounted) {
          setState(() {
            _loadingProgress = 1.0;
          });
        }
        
        // Brief delay to show 100%
        await Future.delayed(const Duration(milliseconds: 300));
        
        // Play the audio from base64 data
        await _audioPlayer.play(BytesSource(
          _base64ToBytes(audioBase64),
          mimeType: 'audio/mpeg',
        ));
        
        if (mounted) {
          setState(() {
            _isPlaying = true;
            _isLoading = false;
            _loadingProgress = 0.0;
          });
        }
      } catch (e) {
        debugPrint('[DeepDive] TTS error: $e');
        _progressTimer?.cancel();
        
        String errorMsg = e.toString();
        
        // Check if this is a usage limit error
        if (errorMsg.contains('usage limit') || 
            errorMsg.contains('permission-denied') || 
            errorMsg.contains('resource-exhausted')) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _loadingProgress = 0.0;
            });
            
            // Get user ID for usage message
            final authStateManager = Provider.of<AuthStateManager>(context, listen: false);
            final uid = authStateManager.userId ?? '';
            
            // Get usage message and show paywall
            PaywallService.getUsageMessage(uid).then((usageMsg) async {
              if (mounted) {
                final subscribed = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (context) => PaywallScreen(
                      message: usageMsg.isEmpty ? errorMsg : usageMsg,
                    ),
                  ),
                );
                
                // If user subscribed, automatically retry TTS
                if (subscribed == true && mounted) {
                  debugPrint('[DeepDive] User subscribed, retrying TTS');
                  await _startSpeaking();
                }
              }
            });
          }
          return;
        }
        
        // For other errors, show snackbar
        if (mounted) {
          setState(() {
            _isLoading = false;
            _loadingProgress = 0.0;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Text-to-speech error: $errorMsg'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[DeepDive] Error starting speech: $e');
      _progressTimer?.cancel();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingProgress = 0.0;
        });
      }
    }
  }

  Future<void> _stopSpeaking() async {
    try {
      await _audioPlayer.stop();
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    } catch (e) {
      debugPrint('[DeepDive] Error stopping speech: $e');
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    }
  }
  
  // Helper method to convert base64 to bytes
  Uint8List _base64ToBytes(String base64String) {
    return base64Decode(base64String);
  }

  @override
  Widget build(BuildContext context) {
    final explanation = widget.coaching['explanation'] ?? '';
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFFF59E0B),
            const Color(0xFFEF4444),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Content
          SafeArea(
            child: SingleChildScrollView(
              controller: _scrollController,
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
                        'DEEP DIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Main content card
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 30,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Icon
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.bolt,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Title
                          const Text(
                            'Your Action Step',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFF1E293B),
                              height: 1.2,
                            ),
                          ),
                          
                          const SizedBox(height: 8),
                          
                          const Text(
                            'Something concrete to do today',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey,
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Content
                          Text(
                            explanation,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              height: 1.6,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
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
                    
                    const SizedBox(height: 120), // Extra space for floating button
                  ],
                ),
              ),
            ),
          ),
          
          // Floating play button (persists on scroll)
          Positioned(
            bottom: 40,
            right: 32,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress indicator when loading
                if (_isLoading)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${(_loadingProgress * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 100,
                          height: 4,
                          child: LinearProgressIndicator(
                            value: _loadingProgress,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0F766E)),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Play/Stop button
                GestureDetector(
                  onTap: _isLoading ? null : _toggleSpeech,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF59E0B), Color(0xFFEF4444)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(20),
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(
                            _isPlaying ? Icons.stop : Icons.play_arrow,
                            color: Colors.white,
                            size: 36,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


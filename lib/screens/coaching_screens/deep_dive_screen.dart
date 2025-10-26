import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_state_manager.dart';
import '../../services/paywall_service.dart';
import '../../services/firebase_service.dart';
import '../../services/analytics_service.dart';
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
  String? _resonance; // null = not set, 'hell_yes' or 'meh'

  @override
  void initState() {
    super.initState();
    _loadVoicePreference();
    // Initialize resonance from coaching data (if already set from previous view)
    final existingResonance = widget.coaching['resonance'];
    if (existingResonance != null && existingResonance.toString().isNotEmpty) {
      _resonance = existingResonance.toString();
    }
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
      final charCount = explanation.length;
      
      // Load historical data to predict generation time
      final prefs = await SharedPreferences.getInstance();
      final historicalData = prefs.getStringList('tts_generation_times') ?? [];
      
      // Calculate expected time based on historical average (or use baseline)
      double expectedMsPerChar = 20.0; // Baseline: 20ms per character (~20 seconds per 1000 chars)
      
      if (historicalData.isNotEmpty) {
        // Parse historical data: "charCount:durationMs"
        double totalChars = 0;
        double totalMs = 0;
        
        for (final entry in historicalData) {
          final parts = entry.split(':');
          if (parts.length == 2) {
            totalChars += double.tryParse(parts[0]) ?? 0;
            totalMs += double.tryParse(parts[1]) ?? 0;
          }
        }
        
        if (totalChars > 0) {
          expectedMsPerChar = totalMs / totalChars;
          debugPrint('[DeepDive] Historical data: ${expectedMsPerChar.toStringAsFixed(2)}ms/char from ${historicalData.length} samples');
        }
      }
      
      double estimatedTotalTime = (charCount * expectedMsPerChar).clamp(5000, 40000);
      debugPrint('[DeepDive] Initial estimate: ${estimatedTotalTime.toInt()}ms for $charCount chars');
      
      // Dynamic progress that adapts in real-time
      _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (!mounted || !_isLoading) {
          timer.cancel();
          return;
        }
        
        final elapsed = DateTime.now().difference(startTime).inMilliseconds.toDouble();
        
        // Adaptive estimation: adjust expected time based on how long it's taking
        // If we're past 50% of estimated time but haven't finished, revise estimate upward
        if (elapsed > estimatedTotalTime * 0.5 && elapsed < estimatedTotalTime * 1.5) {
          // Smoothly adjust estimate based on current pace
          final projectedTotal = elapsed / 0.5; // Project based on reaching 50%
          estimatedTotalTime = (estimatedTotalTime * 0.8) + (projectedTotal * 0.2); // Weighted blend
        }
        
        // Calculate smooth progress with adaptive curve
        double progress;
        final ratio = elapsed / estimatedTotalTime;
        
        if (ratio < 1.0) {
          // Smooth S-curve that reaches ~92% at estimated completion
          // Formula: 0.92 * (1 - e^(-4 * ratio))
          progress = 0.92 * (1 - math.exp(-4 * ratio));
        } else {
          // Past estimated time: creep slowly from 92% toward 98%
          final overtime = ratio - 1.0;
          progress = 0.92 + (0.06 * (1 - math.exp(-2 * overtime)));
        }
        
        setState(() {
          _loadingProgress = progress.clamp(0.0, 0.98);
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
        debugPrint('[DeepDive] Actual generation time: ${actualDuration}ms (estimated: ${estimatedTotalTime.toInt()}ms)');
        
        // Save actual duration for future predictions
        final prefs = await SharedPreferences.getInstance();
        final historicalData = prefs.getStringList('tts_generation_times') ?? [];
        historicalData.add('$charCount:$actualDuration');
        // Keep only last 10 samples for rolling average
        if (historicalData.length > 10) {
          historicalData.removeAt(0);
        }
        await prefs.setStringList('tts_generation_times', historicalData);
        debugPrint('[DeepDive] Saved timing data: ${actualDuration}ms for $charCount chars (${(actualDuration/charCount).toStringAsFixed(2)}ms/char)');
        
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
  
  Future<void> _toggleResonance() async {
    final docId = widget.coaching['id'];
    if (docId == null) {
      debugPrint('[DeepDive] ❌ No document ID found for coaching');
      return;
    }

    final currentResonance = _resonance ?? '';
    // Cycle through: none -> hell_yes -> meh -> none (same as history screen)
    String newResonance;
    if (currentResonance == '') {
      newResonance = 'hell_yes';
    } else if (currentResonance == 'hell_yes') {
      newResonance = 'meh';
    } else {
      newResonance = '';
    }

    debugPrint('[DeepDive] 💚 Resonance toggle initiated');
    debugPrint('[DeepDive]    → Document ID: $docId');
    debugPrint('[DeepDive]    → Previous: "$currentResonance"');
    debugPrint('[DeepDive]    → New: "$newResonance"');

    try {
      // Optimistically update UI
      setState(() {
        _resonance = newResonance;
      });

      // Update the existing document in Firebase (same call as history screen)
      await FirebaseService.updateCoachingResonance(
        docId: docId,
        resonance: newResonance,
      );
      
      await AnalyticsService.logEvent('coaching_resonance', meta: {
        'resonance': newResonance,
        'type': widget.coaching['type'] ?? 'unknown',
      });
      
      debugPrint('[DeepDive] ✅ Resonance successfully updated!');
      debugPrint('[DeepDive]    → State changed from "$currentResonance" to "$newResonance"');
    } catch (e) {
      debugPrint('[DeepDive] ❌ Error updating resonance: $e');
      // Revert on error
      setState(() {
        _resonance = currentResonance;
      });
    }
  }
  
  Widget _buildResonanceIcon() {
    Widget icon;
    String label;
    
    if (_resonance == 'hell_yes') {
      // Red filled heart
      icon = const Icon(
        Icons.favorite,
        color: Colors.red,
        size: 40, // Larger than history (24px)
      );
      label = 'Hell Yes!';
    } else if (_resonance == 'meh') {
      // Black/blue gradient broken heart
      icon = ShaderMask(
        shaderCallback: (bounds) => const LinearGradient(
          colors: [Colors.black, Colors.blue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(bounds),
        child: const Icon(
          Icons.heart_broken,
          color: Colors.white,
          size: 40, // Larger than history (24px)
        ),
      );
      label = 'Meh';
    } else {
      // Empty outline heart
      icon = Icon(
        Icons.favorite_border,
        color: Colors.white.withValues(alpha: 0.7),
        size: 40, // Larger than history (24px)
      );
      label = 'No Comment';
    }
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14, // Larger than history (9px)
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
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
              physics: const ClampingScrollPhysics(),
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
                    
                    // Resonance feedback icon (tappable, cycles through states)
                    const SizedBox(height: 32),
                    Center(
                      child: GestureDetector(
                        onTap: _toggleResonance,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: _buildResonanceIcon(),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
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


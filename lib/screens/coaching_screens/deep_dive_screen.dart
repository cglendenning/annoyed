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
  List<String>? _audioChunksBase64; // Store all audio chunks
  int _currentChunkIndex = 0;
  String _selectedVoice = 'nova';
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
    // Listen for audio completion to play next chunk
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        _playNextChunk();
      }
    });
  }
  
  Future<void> _playNextChunk() async {
    if (_audioChunksBase64 != null && _currentChunkIndex < _audioChunksBase64!.length - 1) {
      // Check if next chunk is ready
      if (_currentChunkIndex + 1 < _audioChunksBase64!.length) {
        // Next chunk is ready, play it
        _currentChunkIndex++;
        debugPrint('[DeepDive] Playing chunk ${_currentChunkIndex + 1}/${_audioChunksBase64!.length}');
        
        await _audioPlayer.play(BytesSource(
          _base64ToBytes(_audioChunksBase64![_currentChunkIndex]),
          mimeType: 'audio/mpeg',
        ));
      } else {
        // Next chunk not ready yet, wait for it
        debugPrint('[DeepDive] Waiting for next chunk to buffer...');
        
        // Poll for next chunk (with timeout)
        final startWait = DateTime.now();
        while (_audioChunksBase64 == null || _currentChunkIndex + 1 >= _audioChunksBase64!.length) {
          await Future.delayed(const Duration(milliseconds: 100));
          
          if (DateTime.now().difference(startWait).inSeconds > 30) {
            debugPrint('[DeepDive] Timeout waiting for next chunk');
            if (mounted) {
              setState(() {
                _isPlaying = false;
              });
            }
            return;
          }
        }
        
        // Play the now-ready chunk
        _currentChunkIndex++;
        debugPrint('[DeepDive] Buffered chunk ${_currentChunkIndex + 1}/${_audioChunksBase64!.length} ready');
        
        await _audioPlayer.play(BytesSource(
          _base64ToBytes(_audioChunksBase64![_currentChunkIndex]),
          mimeType: 'audio/mpeg',
        ));
      }
    } else {
      // All chunks played
      debugPrint('[DeepDive] All audio chunks completed');
      if (mounted) {
        setState(() {
          _isPlaying = false;
        });
      }
    }
  }
  
  List<String> _splitTextIntoChunks(String text, int maxChars) {
    // Split text into chunks, trying to break at sentence boundaries
    final chunks = <String>[];
    var remaining = text;
    
    while (remaining.length > maxChars) {
      // Try to find a sentence end near maxChars
      var breakPoint = maxChars;
      final searchStart = math.max(0, maxChars - 200);
      final searchEnd = math.min(remaining.length, maxChars + 100);
      final searchText = remaining.substring(searchStart, searchEnd);
      
      // Look for sentence endings
      final sentenceEnd = RegExp(r'[.!?]\s+').allMatches(searchText).lastOrNull;
      if (sentenceEnd != null) {
        breakPoint = searchStart + sentenceEnd.end;
      }
      
      chunks.add(remaining.substring(0, breakPoint).trim());
      remaining = remaining.substring(breakPoint).trim();
    }
    
    if (remaining.isNotEmpty) {
      chunks.add(remaining);
    }
    
    return chunks;
  }
  
  Future<void> _loadVoicePreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedVoice = prefs.getString('tts_voice') ?? 'nova';
    });
  }

  @override
  void dispose() {
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
      
      // If already cached, just play from start
      if (_audioChunksBase64 != null && _audioChunksBase64!.isNotEmpty) {
        _currentChunkIndex = 0;
        await _audioPlayer.play(BytesSource(
          _base64ToBytes(_audioChunksBase64![0]),
          mimeType: 'audio/mpeg',
        ));
        if (mounted) {
          setState(() {
            _isPlaying = true;
          });
        }
        return;
      }
      
      // Split text into chunks (~1000 chars each, at sentence boundaries)
      final textChunks = _splitTextIntoChunks(explanation, 1000);
      debugPrint('[DeepDive] Split ${explanation.length} chars into ${textChunks.length} chunks');
      
      // Start loading
      setState(() {
        _isLoading = true;
      });
      
      final overallStartTime = DateTime.now();
      final audioChunks = <String>[];
      
      try {
        // Generate first chunk and measure network speed
        debugPrint('[DeepDive] Generating chunk 1/${textChunks.length} (${textChunks[0].length} chars)');
        final firstChunkStart = DateTime.now();
        
        final firstResult = await FirebaseFunctions.instance
            .httpsCallable('generateTTS')
            .call({
              'text': textChunks[0],
              'voice': _selectedVoice,
            });
        
        final firstChunkDuration = DateTime.now().difference(firstChunkStart).inMilliseconds;
        audioChunks.add(firstResult.data['audioBase64'] as String);
        
        // Estimate audio playback duration (rough estimate: 150 words/min = ~13 chars/sec of audio)
        final estimatedPlaybackMs = (textChunks[0].length / 13 * 1000).toInt();
        
        // Calculate network speed ratio (generation time / playback time)
        final speedRatio = firstChunkDuration / estimatedPlaybackMs;
        
        debugPrint('[DeepDive] First chunk: ${firstChunkDuration}ms generation, ~${estimatedPlaybackMs}ms playback, ratio: ${speedRatio.toStringAsFixed(2)}');
        
        // Adaptive buffering: decide how many chunks to buffer before starting
        int chunksToBuffer = 1; // Default: start immediately
        
        if (speedRatio > 2.0) {
          // Very slow network: buffer 3 chunks
          chunksToBuffer = math.min(3, textChunks.length);
          debugPrint('[DeepDive] Slow network detected, buffering $chunksToBuffer chunks');
        } else if (speedRatio > 1.2) {
          // Moderate network: buffer 2 chunks
          chunksToBuffer = math.min(2, textChunks.length);
          debugPrint('[DeepDive] Moderate network detected, buffering $chunksToBuffer chunks');
        } else {
          // Fast network: start immediately
          debugPrint('[DeepDive] Fast network detected, starting playback immediately');
        }
        
        // Buffer additional chunks if needed
        if (chunksToBuffer > 1 && textChunks.length > 1) {
          for (int i = 1; i < chunksToBuffer && i < textChunks.length; i++) {
            debugPrint('[DeepDive] Buffering chunk ${i + 1}/${textChunks.length}');
            final result = await FirebaseFunctions.instance
                .httpsCallable('generateTTS')
                .call({
                  'text': textChunks[i],
                  'voice': _selectedVoice,
                });
            audioChunks.add(result.data['audioBase64'] as String);
          }
          debugPrint('[DeepDive] Buffered ${audioChunks.length} chunks, starting playback');
        }
        
        // Start playing first chunk
        _audioChunksBase64 = audioChunks;
        _currentChunkIndex = 0;
        
        await _audioPlayer.play(BytesSource(
          _base64ToBytes(audioChunks[0]),
          mimeType: 'audio/mpeg',
        ));
        
        if (mounted) {
          setState(() {
            _isPlaying = true;
            _isLoading = false;
          });
        }
        
        // Generate remaining chunks in background
        if (audioChunks.length < textChunks.length) {
          _generateRemainingChunks(textChunks, audioChunks, overallStartTime);
        }
        
      } catch (e) {
        debugPrint('[DeepDive] TTS error: $e');
        
        String errorMsg = e.toString();
        
        // Check if this is a usage limit error
        if (errorMsg.contains('usage limit') || 
            errorMsg.contains('permission-denied') || 
            errorMsg.contains('resource-exhausted')) {
          if (mounted) {
            setState(() {
              _isLoading = false;
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
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _generateRemainingChunks(
    List<String> textChunks,
    List<String> audioChunks,
    DateTime overallStartTime,
  ) async {
    try {
      final startIndex = audioChunks.length; // Start from where we left off
      debugPrint('[DeepDive] Generating remaining ${textChunks.length - startIndex} chunks in background');
      
      for (int i = startIndex; i < textChunks.length; i++) {
        debugPrint('[DeepDive] Generating chunk ${i + 1}/${textChunks.length} (${textChunks[i].length} chars)');
        
        final result = await FirebaseFunctions.instance
            .httpsCallable('generateTTS')
            .call({
              'text': textChunks[i],
              'voice': _selectedVoice,
            });
        
        audioChunks.add(result.data['audioBase64'] as String);
        
        // Update cached chunks atomically
        if (mounted) {
          setState(() {
            _audioChunksBase64 = List.from(audioChunks);
          });
        }
        
        debugPrint('[DeepDive] Chunk ${i + 1}/${textChunks.length} ready (${audioChunks.length} total cached)');
      }
      
      final totalDuration = DateTime.now().difference(overallStartTime).inMilliseconds;
      debugPrint('[DeepDive] All chunks generated in ${totalDuration}ms');
      
      // Save timing data for future predictions
      final prefs = await SharedPreferences.getInstance();
      final historicalData = prefs.getStringList('tts_generation_times') ?? [];
      final totalChars = textChunks.fold(0, (sum, chunk) => sum + chunk.length);
      historicalData.add('$totalChars:$totalDuration');
      if (historicalData.length > 10) {
        historicalData.removeAt(0);
      }
      await prefs.setStringList('tts_generation_times', historicalData);
      
    } catch (e) {
      debugPrint('[DeepDive] Error generating remaining chunks: $e');
      // Don't show error to user - they're already listening to first/buffered chunks
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


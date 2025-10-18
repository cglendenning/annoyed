import 'package:flutter/material.dart';
import 'dart:async';
import '../utils/app_colors.dart';
import '../widgets/animated_gradient_container.dart';

class TapToRecordButton extends StatefulWidget {
  final bool isRecording;
  final bool isSaving;
  final String transcript;
  final VoidCallback onStartRecording;
  final VoidCallback onStopRecording;
  final VoidCallback onCancelRecording;
  final int maxDurationSeconds;

  const TapToRecordButton({
    super.key,
    required this.isRecording,
    required this.isSaving,
    required this.transcript,
    required this.onStartRecording,
    required this.onStopRecording,
    required this.onCancelRecording,
    this.maxDurationSeconds = 30,
  });

  @override
  State<TapToRecordButton> createState() => _TapToRecordButtonState();
}

class _TapToRecordButtonState extends State<TapToRecordButton> {
  Timer? _timer;
  int _secondsRemaining = 0;

  @override
  void initState() {
    super.initState();
    _secondsRemaining = widget.maxDurationSeconds;
  }

  @override
  void didUpdateWidget(TapToRecordButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Start timer when recording starts
    if (!oldWidget.isRecording && widget.isRecording) {
      _startTimer();
    }
    
    // Stop timer when recording stops
    if (oldWidget.isRecording && !widget.isRecording) {
      _stopTimer();
      _secondsRemaining = widget.maxDurationSeconds;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _secondsRemaining = widget.maxDurationSeconds;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _stopTimer();
        widget.onStopRecording();
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _handleTap() {
    if (widget.isRecording) {
      widget.onStopRecording();
    } else {
      widget.onStartRecording();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isSaving) {
      return _buildSavingState();
    }

    if (widget.isRecording) {
      return _buildRecordingState(context);
    }

    return _buildIdleState();
  }

  Widget _buildIdleState() {
    return GestureDetector(
      onTap: _handleTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AnimatedGradientContainer(
          colors: const [
            AppColors.primaryTealLight,
            AppColors.primaryTeal,
            AppColors.primaryTealDark,
          ],
          duration: const Duration(seconds: 3),
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0x4D0F766E), // 30% opacity
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.mic,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'TAP TO RECORD (${widget.maxDurationSeconds}s)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tap again to stop',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingState(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AnimatedGradientContainer(
          colors: const [
            AppColors.accentCoralLight,
            AppColors.accentCoral,
            Color(0xFF991B1B), // deeper red
          ],
          duration: const Duration(seconds: 2),
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4DEF4444), // coral at 30% opacity
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    value: _secondsRemaining / widget.maxDurationSeconds,
                    strokeWidth: 4,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    backgroundColor: Colors.white30,
                  ),
                ),
                Text(
                  '$_secondsRemaining',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
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
            const SizedBox(height: 4),
            const Text(
              'Tap to stop',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            if (widget.transcript.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  widget.transcript,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: widget.onCancelRecording,
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSavingState() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Saving...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


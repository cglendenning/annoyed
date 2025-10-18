import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../providers/auth_provider.dart';
import '../providers/annoyance_provider.dart';
import '../services/speech_service.dart';
import '../services/firebase_service.dart';
import '../widgets/tap_to_record_button.dart';
import '../widgets/category_chip.dart';
import '../widgets/animated_gradient_container.dart';
import '../utils/app_colors.dart';
import '../utils/constants.dart';
import 'history_screen.dart';
import 'profile_screen.dart';
import 'settings_screen.dart';
import 'entry_detail_screen.dart';
import 'pattern_report_screen.dart';
import 'coaching_screen.dart';
import 'auth_gate_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SpeechService _speechService = SpeechService();
  final TextEditingController _textController = TextEditingController();
  bool _isRecording = false;
  bool _isSaving = false;
  String _transcript = '';
  bool _hasShownPatternReport = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final annoyanceProvider =
        Provider.of<AnnoyanceProvider>(context, listen: false);

    final uid = authProvider.userId;
    if (uid != null) {
      await annoyanceProvider.loadAnnoyances(uid);

      // Check if we should show pattern report (only once per session)
      final patternReport = annoyanceProvider.getPatternReport();
      if (patternReport != null && !_hasShownPatternReport && mounted) {
        _hasShownPatternReport = true;
        // Show pattern report after 3rd entry
        Future.microtask(() {
          if (mounted) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const PatternReportScreen(),
              ),
            );
          }
        });
      }
    }
  }

  void _startRecording() async {
    setState(() {
      _isRecording = true;
      _transcript = '';
    });

    try {
      await _speechService.startListening(
        onResult: (text) {
          setState(() {
            _transcript = text;
          });
        },
        onComplete: () {
          _stopRecording();
        },
      );
    } catch (e) {
      // Permission denied or speech recognition not available
      setState(() {
        _isRecording = false;
        _transcript = '';
      });
      
      print('Speech error: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Microphone permission is required to record'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () async {
                await openAppSettings();
              },
            ),
          ),
        );
      }
    }
  }

  void _stopRecording() async {
    await _speechService.stopListening();
    setState(() {
      _isRecording = false;
    });

    if (_transcript.isNotEmpty) {
      await _saveAnnoyance(_transcript);
    }
  }

  void _cancelRecording() async {
    await _speechService.cancel();
    setState(() {
      _isRecording = false;
      _transcript = '';
    });
  }

  Future<void> _saveAnnoyance(String transcript) async {
    if (transcript.trim().isEmpty) return;

    setState(() {
      _isSaving = true;
    });

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final annoyanceProvider =
        Provider.of<AnnoyanceProvider>(context, listen: false);

    final uid = authProvider.userId;
    if (uid != null) {
      // Show transcribing snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transcribing...'),
            duration: Duration(seconds: 1),
          ),
        );
      }

      final id = await annoyanceProvider.saveAnnoyance(
        uid: uid,
        transcript: transcript,
      );

      if (id != null && mounted) {
        // Show categorizing snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Categorizing...'),
            duration: Duration(seconds: 1),
          ),
        );

        // Wait a bit then show saved snackbar
        await Future.delayed(const Duration(milliseconds: AppConstants.snackbarShortDelayMs));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Saved'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
          
          final annoyanceCount = annoyanceProvider.annoyances.length;
          final isAnonymous = authProvider.user?.isAnonymous ?? false;
          
          // Check if this is the configured annoyance count and user is anonymous (show auth gate)
          if (annoyanceCount == AppConstants.annoyancesForAuthGate && isAnonymous) {
            await Future.delayed(const Duration(milliseconds: 1500));
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AuthGateScreen(
                    message: 'You\'re on a roll! 🎉',
                    subtitle: 'You\'ve recorded 5 annoyances. Sign up now to unlock coaching insights and keep your progress forever!',
                  ),
                ),
              );
            }
          }
          // Auto-generate coaching: after 1st annoyance, then every 5 NEW annoyances after that
          // Pattern: annoyance #1 -> coaching #1, annoyance #6 -> coaching #2, annoyance #11 -> coaching #3, etc.
          else if (await _shouldGenerateNewCoaching(uid, annoyanceCount)) {
            await Future.delayed(const Duration(milliseconds: 1500));
            if (mounted) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => CoachingScreen(forceRegenerate: true),
                ),
              );
            }
          }
        }
      }
    }

    setState(() {
      _isSaving = false;
      _transcript = '';
    });
  }

  void _submitTextEntry() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    await _saveAnnoyance(text);
    _textController.clear();
  }
  
  Future<bool> _shouldGenerateNewCoaching(String uid, int currentAnnoyanceCount) async {
    // Get count of existing coachings
    final coachings = await FirebaseService.getAllCoachings(uid: uid);
    final coachingCount = coachings.length;
    
    // First coaching should happen at annoyance #1
    if (coachingCount == 0 && currentAnnoyanceCount == 1) {
      return true;
    }
    
    // After that, generate coaching every N annoyances
    // Coaching #1 at annoyance 1, #2 at annoyance 6, #3 at annoyance 11, etc.
    // Formula: next coaching should be at annoyance count = 1 + (coachingCount * N)
    final nextCoachingAt = 1 + (coachingCount * AppConstants.annoyancesPerCoaching);
    
    return currentAnnoyanceCount == nextCoachingAt;
  }

  @override
  Widget build(BuildContext context) {
    Provider.of<AuthProvider>(context);
    final annoyanceProvider = Provider.of<AnnoyanceProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Annoyed',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tap to record button
              TapToRecordButton(
                isRecording: _isRecording,
                isSaving: _isSaving,
                transcript: _transcript,
                onStartRecording: _startRecording,
                onStopRecording: _stopRecording,
                onCancelRecording: _cancelRecording,
                maxDurationSeconds: AppConstants.maxRecordingSeconds,
              ),

              const SizedBox(height: 12),

              // Type instead option (hide during recording/saving)
              if (!_isRecording && !_isSaving)
                Center(
                  child: TextButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Type Instead'),
                          content: TextField(
                            controller: _textController,
                            decoration: const InputDecoration(
                              hintText: 'What annoyed you?',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 3,
                            autofocus: true,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _submitTextEntry();
                              },
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                      );
                    },
                    child: const Text('Type instead'),
                  ),
                ),

              const SizedBox(height: 24),

              // Coaching button - only show if user has entries
              if (!_isRecording && !_isSaving && annoyanceProvider.annoyances.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedGradientContainer(
                    colors: const [
                      AppColors.primaryTealLight,
                      AppColors.primaryTeal,
                      AppColors.accentCoral,
                    ],
                    duration: const Duration(seconds: 4),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0x660F766E), // primaryTeal at 40% opacity
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const CoachingScreen(),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(
                                    color: Color(0x33FFFFFF), // white at 20% opacity
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.lightbulb,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Get Your Coaching',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Personalized insights from your patterns',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              if (!_isRecording && !_isSaving && annoyanceProvider.annoyances.isNotEmpty)
                const SizedBox(height: 24),

              // Recent entries
              if (annoyanceProvider.todayAnnoyances.isNotEmpty) ...[
                Row(
                  children: [
                    const Text(
                      'Recent (today)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const HistoryScreen(),
                          ),
                        );
                      },
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    itemCount: annoyanceProvider.todayAnnoyances.length,
                    itemBuilder: (context, index) {
                      final annoyance =
                          annoyanceProvider.todayAnnoyances[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  annoyance.transcript,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (annoyance.modified) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.edit,
                                  size: 14,
                                  color: Colors.blue.shade700,
                                ),
                              ],
                            ],
                          ),
                          trailing: CategoryChip(category: annoyance.category),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    EntryDetailScreen(annoyance: annoyance),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],

              if (annoyanceProvider.todayAnnoyances.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.mic_none,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Hold to record your first annoyance',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Bottom buttons
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ProfileScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.analytics_outlined),
                      label: const Text('Profile'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const HistoryScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.history),
                      label: const Text('History'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}


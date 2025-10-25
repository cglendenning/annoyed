import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_state_manager.dart';
import '../providers/annoyance_provider.dart';
import 'coaching_screens/mindset_shift_screen.dart';
import 'coaching_screens/deep_dive_screen.dart';
import 'coaching_screens/annoyance_analysis_screen.dart';
import 'coaching_screens/wisdom_cta_screen.dart';

/// Main coaching flow that presents 4 swipeable screens
class CoachingFlowScreen extends StatefulWidget {
  final Map<String, dynamic> coaching;
  
  const CoachingFlowScreen({
    super.key,
    required this.coaching,
  });

  @override
  State<CoachingFlowScreen> createState() => _CoachingFlowScreenState();
}

class _CoachingFlowScreenState extends State<CoachingFlowScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authStateManager = Provider.of<AuthStateManager>(context, listen: false);
    final annoyanceProvider = Provider.of<AnnoyanceProvider>(context, listen: false);
    final uid = authStateManager.userId ?? '';

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (page) {
              setState(() {
                _currentPage = page;
              });
            },
            children: [
              // Screen 1: Mindset Shift
              MindsetShiftScreen(
                coaching: widget.coaching,
                onSwipeRight: _nextPage,
              ),
              
              // Screen 2: Deep Dive (Action Step)
              DeepDiveScreen(
                coaching: widget.coaching,
                onSwipeLeft: _nextPage,
                onSwipeRight: _previousPage,
              ),
              
              // Screen 3: Annoyance Analysis
              AnnoyanceAnalysisScreen(
                uid: uid,
                annoyanceProvider: annoyanceProvider,
                onSwipeLeft: _nextPage,
                onSwipeRight: _previousPage,
              ),
              
              // Screen 4: Wisdom & CTA
              WisdomCtaScreen(
                onSwipeRight: _previousPage,
              ),
            ],
          ),
          
          // Page indicator
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == index ? 32 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == index
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
          
          // Close button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}


import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:intl/intl.dart';
import '../utils/app_colors.dart';
import 'cancel_subscription_screen.dart';
import 'paywall_screen.dart';

class SubscriptionStatusScreen extends StatefulWidget {
  const SubscriptionStatusScreen({super.key});

  @override
  State<SubscriptionStatusScreen> createState() => _SubscriptionStatusScreenState();
}

class _SubscriptionStatusScreenState extends State<SubscriptionStatusScreen>
    with TickerProviderStateMixin {
  CustomerInfo? _customerInfo;
  bool _loading = true;
  String? _error;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize pulse animation for the resubscribe button
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fetchSubscriptionStatus();
  }

  Future<void> _fetchSubscriptionStatus() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await Purchases.invalidateCustomerInfoCache();

      if (kDebugMode) {
        print('[DEBUG] Forcing sync with store...');
      }
      await Purchases.syncPurchases();

      CustomerInfo info = await Purchases.getCustomerInfo();
      if (kDebugMode) {
        print('[DEBUG] CustomerInfo: ${info.toString()}');
      }
      setState(() {
        _customerInfo = info;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to fetch subscription status: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _error == null) {
      final activeSubs = _customerInfo?.activeSubscriptions ?? [];
      final allEntitlements = _customerInfo?.entitlements.active ?? {};
      if (activeSubs.isEmpty && allEntitlements.isEmpty) {
        // Route to paywall after build completes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const PaywallScreen()),
          );
        });
      }
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription Status'),
        backgroundColor: AppColors.primaryTeal,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.red)))
                : _buildStatus(context),
      ),
    );
  }

  Widget _buildStatus(BuildContext context) {
    final activeSubs = _customerInfo?.activeSubscriptions ?? [];
    final allEntitlements = _customerInfo?.entitlements.active ?? {};
    final allProductIds = _customerInfo?.allPurchasedProductIdentifiers ?? [];
    final latestExpiration = _customerInfo?.latestExpirationDate;

    if (activeSubs.isEmpty && allEntitlements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.info_outline, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text('No active subscription found.',
                style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }

    // Find the most recent entitlement (if any)
    final entitlement =
        allEntitlements.isNotEmpty ? allEntitlements.values.first : null;
    if (entitlement != null && kDebugMode) {
      print('[DEBUG] Entitlement: ${entitlement.toString()}');
    }
    final planId = entitlement?.productIdentifier ??
        (activeSubs.isNotEmpty
            ? activeSubs.first
            : (allProductIds.isNotEmpty ? allProductIds.last : 'Unknown'));
    final isActive = activeSubs.isNotEmpty;
    final expirationDate = entitlement?.expirationDate ?? latestExpiration;

    DateTime? parsedExpiration =
        expirationDate != null ? DateTime.tryParse(expirationDate) : null;

    String status = isActive ? 'Active' : 'Cancelled';
    String plan = planId;
    String renewal = parsedExpiration != null
        ? DateFormat.yMMMMd().add_jm().format(parsedExpiration.toLocal())
        : 'Unknown';

    // Check if subscription is cancelled but not expired yet
    bool isCancelledButNotExpired = false;

    if (kDebugMode) {
      print('[DEBUG] Subscription Status Debug:');
      print('[DEBUG] - isActive: $isActive');
      print('[DEBUG] - activeSubs: $activeSubs');
      print('[DEBUG] - parsedExpiration: $parsedExpiration');
    }

    // Check entitlement willRenew status
    for (final entry in (_customerInfo?.entitlements.all ?? {}).entries) {
      final ent = entry.value;
      if (kDebugMode) {
        print('[DEBUG] - Entitlement ${entry.key}: willRenew=${ent.willRenew}');
      }
      if (ent.willRenew == false && ent.expirationDate != null) {
        final expDate = DateTime.tryParse(ent.expirationDate!);
        if (expDate != null && expDate.isAfter(DateTime.now())) {
          isCancelledButNotExpired = true;
          break;
        }
      }
    }

    // Start pulse animation if subscription is cancelled but not expired
    if (isCancelledButNotExpired && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!isCancelledButNotExpired && _pulseController.isAnimating) {
      _pulseController.stop();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(
              isActive ? Icons.verified : Icons.cancel,
              color: isActive ? Colors.green : Colors.red,
              size: 32,
            ),
            const SizedBox(width: 12),
            const Text(
              'Subscription Status',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 32),
        _infoRow('Plan', plan),
        _infoRow('Status', status),
        _infoRow(
            isCancelledButNotExpired
                ? 'Expires On'
                : (isActive ? 'Next Renewal' : 'Access Until'),
            renewal),
        const SizedBox(height: 32),
        Center(
          child: ElevatedButton.icon(
            onPressed: _fetchSubscriptionStatus,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryTeal,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        if (isActive && !isCancelledButNotExpired) ...[
          const SizedBox(height: 32),
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.cancel),
              label: const Text('Cancel Subscription'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const CancelSubscriptionScreen()),
                );
                // Refresh status after returning
                _fetchSubscriptionStatus();
              },
            ),
          ),
        ],
        if (isCancelledButNotExpired)
          Padding(
            padding: const EdgeInsets.only(top: 24.0),
            child: Column(
              children: [
                // Message about the cancellation
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.orange.withOpacity(0.1),
                        Colors.red.withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.sentiment_dissatisfied,
                              color: Colors.orange, size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Oh no! You\'re leaving us? 😢',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your subscription is cancelled but you\'ll have access until $renewal. We\'ll miss you! 💔',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Resubscribe button with pulse animation
                AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            // Navigate to paywall to resubscribe
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => const PaywallScreen()),
                            );
                            // Refresh status after returning
                            _fetchSubscriptionStatus();

                            // Show celebration if user resubscribed
                            if (result == true) {
                              _showResubscriptionCelebration();
                            }
                          },
                          icon: const Icon(Icons.favorite, color: Colors.white),
                          label: const Text(
                            'Actually, I\'ll Stay! 💚',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryTeal,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // Small print about uncancelling
                const Text(
                  'Tap above to resubscribe and continue your journey!',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          SizedBox(
              width: 120,
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.bold))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showResubscriptionCelebration() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.celebration,
                size: 64,
                color: AppColors.primaryTeal,
              ),
              const SizedBox(height: 16),
              Text(
                'Welcome Back! 🎉',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryTeal,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'We\'re so glad you decided to stay! Your subscription is now active again.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Awesome! 💚',
                style: TextStyle(
                  color: AppColors.primaryTeal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
}




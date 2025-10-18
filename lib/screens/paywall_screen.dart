import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../providers/auth_provider.dart';
import '../providers/preferences_provider.dart';
import '../services/analytics_service.dart';

class PaywallScreen extends StatefulWidget {
  final String? message;
  final String? subtitle;
  
  const PaywallScreen({super.key, this.message, this.subtitle});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isLoading = false;
  Offerings? _offerings;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
    AnalyticsService.logPaywallView();
  }

  Future<void> _loadOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      setState(() {
        _offerings = offerings;
      });
    } catch (e) {
      debugPrint('Error loading offerings: $e');
    }
  }

  Future<void> _purchasePackage(Package package) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final customerInfo = await Purchases.purchasePackage(package);
      
      // Check if user is now pro
      if (customerInfo.entitlements.all['pro']?.isActive == true) {
        // Update user preferences
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final prefsProvider =
            Provider.of<PreferencesProvider>(context, listen: false);

        final uid = authProvider.userId;
        if (uid != null) {
          // Set pro_until to a year from now (or based on subscription)
          final proUntil = DateTime.now().add(const Duration(days: 365));
          await prefsProvider.updateProStatus(uid: uid, proUntil: proUntil);
        }

        await AnalyticsService.logTrialStart();

        if (mounted) {
          Navigator.of(context).pop(true); // Return true to indicate success
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Welcome to Annoyed Pro!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Purchase failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final customerInfo = await Purchases.restorePurchases();
      
      if (customerInfo.entitlements.all['pro']?.isActive == true) {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final prefsProvider =
            Provider.of<PreferencesProvider>(context, listen: false);

        final uid = authProvider.userId;
        if (uid != null) {
          final proUntil = DateTime.now().add(const Duration(days: 365));
          await prefsProvider.updateProStatus(uid: uid, proUntil: proUntil);
        }

        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Purchases restored!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No active subscriptions found'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Annoyed Pro'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _restorePurchases,
            child: const Text('Restore'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.stars,
                    size: 80,
                    color: Color(0xFF0F766E),
                  ),
                  const SizedBox(height: 24),
                  
                  // Custom message if provided (for usage limits)
                  if (widget.message != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Text(
                        widget.message!,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  
                  Text(
                    widget.message != null ? 'Subscribe to Continue' : 'Upgrade to Pro',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      widget.subtitle!,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  
                  const SizedBox(height: 32),

                  // Features
                  _FeatureTile(
                    icon: Icons.timer,
                    title: 'Longer recordings',
                    subtitle: '90-second captures',
                  ),
                  _FeatureTile(
                    icon: Icons.insights,
                    title: 'Deeper pattern insights',
                    subtitle: 'Advanced analytics and trends',
                  ),
                  _FeatureTile(
                    icon: Icons.schedule,
                    title: 'Custom preferred hours',
                    subtitle: 'Fine-tune coach check-in times',
                  ),
                  _FeatureTile(
                    icon: Icons.flash_on,
                    title: 'Higher suggestion frequency',
                    subtitle: 'Get suggestions more often',
                  ),
                  _FeatureTile(
                    icon: Icons.support_agent,
                    title: 'Priority support',
                    subtitle: 'Fast response to questions',
                  ),

                  const SizedBox(height: 32),

                  // Pricing
                  if (_offerings?.current?.availablePackages.isNotEmpty ??
                      false) ...[
                    ...(_offerings!.current!.availablePackages.map((package) {
                      final isAnnual =
                          package.packageType == PackageType.annual;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _PricingCard(
                          package: package,
                          isRecommended: isAnnual,
                          onTap: () => _purchasePackage(package),
                        ),
                      );
                    })),
                  ] else ...[
                    // Fallback pricing if RevenueCat isn't configured yet
                    _FallbackPricingCard(
                      title: 'Annual',
                      price: '\$24.99/year',
                      isRecommended: true,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'RevenueCat not configured. Please set up in-app purchases.'),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    _FallbackPricingCard(
                      title: 'Monthly',
                      price: '\$3.99/month',
                      isRecommended: false,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'RevenueCat not configured. Please set up in-app purchases.'),
                          ),
                        );
                      },
                    ),
                  ],

                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Maybe later'),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    '7-day free trial • Cancel anytime',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
    );
  }
}

extension on PurchaseResult {
  get entitlements => null;
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF0F766E)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
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

class _PricingCard extends StatelessWidget {
  final Package package;
  final bool isRecommended;
  final VoidCallback onTap;

  const _PricingCard({
    required this.package,
    required this.isRecommended,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isRecommended
              ? const Color(0xFF0F766E).withOpacity(0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isRecommended
                ? const Color(0xFF0F766E)
                : Colors.grey.shade300,
            width: isRecommended ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    package.storeProduct.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isRecommended) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'BEST VALUE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              package.storeProduct.priceString,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F766E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FallbackPricingCard extends StatelessWidget {
  final String title;
  final String price;
  final bool isRecommended;
  final VoidCallback onTap;

  const _FallbackPricingCard({
    required this.title,
    required this.price,
    required this.isRecommended,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isRecommended
              ? const Color(0xFF0F766E).withOpacity(0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isRecommended
                ? const Color(0xFF0F766E)
                : Colors.grey.shade300,
            width: isRecommended ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (isRecommended) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'BEST VALUE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              price,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F766E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}






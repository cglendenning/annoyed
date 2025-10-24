import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../providers/auth_state_manager.dart';
import '../providers/preferences_provider.dart';
import '../services/analytics_service.dart';
import 'post_subscription_screen.dart';

class PaywallScreen extends StatefulWidget {
  final String? message;
  final String? subtitle;
  
  const PaywallScreen({super.key, this.message, this.subtitle});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isLoading = false;
  List<StoreProduct> _products = [];
  String? _errorDetails;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    AnalyticsService.logPaywallView();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorDetails = null;
    });
    
    try {
      debugPrint('[RevenueCat] Loading products directly...');
      final products = await Purchases.getProducts(
        ['com.cglendenning.annoyed.premium.monthly', 'com.cglendenning.annoyed.premium.annual'],
        productCategory: ProductCategory.subscription,
      );
      debugPrint('[RevenueCat] Products loaded: ${products.length}');
      for (var product in products) {
        debugPrint('[RevenueCat] - ${product.identifier}: ${product.priceString}');
      }
      
      if (products.isEmpty) {
        setState(() {
          _errorDetails = 'No products found. Check:\n• Products exist in App Store Connect\n• Products have metadata\n• Bundle ID matches';
        });
      }
      
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('[RevenueCat] Error loading products: $e');
      debugPrint('[RevenueCat] Stack trace: $stackTrace');
      setState(() {
        _errorDetails = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _purchaseProduct(StoreProduct product) async {
    setState(() {
      _isLoading = true;
    });

    // Get providers before any async operations to avoid BuildContext issues
    final authStateManager = Provider.of<AuthStateManager>(context, listen: false);
    final prefsProvider = Provider.of<PreferencesProvider>(context, listen: false);

    try {
      // Just call purchaseStoreProduct - if it succeeds without throwing, we're good
      // ignore: deprecated_member_use
      await Purchases.purchaseStoreProduct(product);
      
      // If we get here, purchase succeeded - activate premium
      final uid = authStateManager.userId;
      if (uid != null) {
        final proUntil = DateTime.now().add(const Duration(days: 365));
        await prefsProvider.updateProStatus(uid: uid, proUntil: proUntil);
      }

      await AnalyticsService.logTrialStart();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // Navigate to post-subscription screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const PostSubscriptionScreen(),
          ),
        );
      }
    } on PlatformException catch (e) {
      debugPrint('[PaywallScreen] Purchase error: ${e.code} - ${e.message}');
      debugPrint('[PaywallScreen] Error details: ${e.details}');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      
      // Error code 8 = INVALID_RECEIPT
      // This often happens in sandbox/TestFlight but purchase may have succeeded
      if (e.code == '8') {
        debugPrint('[PaywallScreen] Receipt validation error - checking if purchase actually succeeded');
        
        // Wait a moment and check subscription status
        await Future.delayed(const Duration(seconds: 1));
        
        try {
          // Sync and check status
          await Purchases.syncPurchases();
          final customerInfo = await Purchases.getCustomerInfo();
          
          debugPrint('[PaywallScreen] Post-error check: premium=${customerInfo.entitlements.all['premium']?.isActive}');
          
          // If premium is active, the purchase actually succeeded despite the error
          if (customerInfo.entitlements.all['premium']?.isActive == true) {
            debugPrint('[PaywallScreen] Purchase succeeded despite receipt error!');
            
            // Use authStateManager and prefsProvider already obtained at the start of the function
            final uid = authStateManager.userId;
            if (uid != null) {
              final proUntil = DateTime.now().add(const Duration(days: 365));
              await prefsProvider.updateProStatus(uid: uid, proUntil: proUntil);
            }

            await AnalyticsService.logTrialStart();

            if (mounted) {
              // Navigate to success screen
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const PostSubscriptionScreen(),
                ),
              );
            }
            return; // Success - exit early
          }
        } catch (checkError) {
          debugPrint('[PaywallScreen] Error checking subscription status: $checkError');
        }
        
        // Purchase didn't work - show helpful message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Receipt validation failed. This sometimes happens in test mode. Try "Restore Purchases" to verify your subscription.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 6),
            ),
          );
        }
      } else if (!e.details.toString().contains('userCancelled: true')) {
        // Other errors (that aren't user cancellation)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Purchase failed: ${e.message ?? e.code}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      // Any other error type
      debugPrint('[PaywallScreen] Unexpected purchase error: $e');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (!e.toString().contains('UserCancelled')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Purchase failed: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  Future<void> _restorePurchases() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authStateManager = Provider.of<AuthStateManager>(context, listen: false);
      final prefsProvider = Provider.of<PreferencesProvider>(context, listen: false);
      
      final customerInfo = await Purchases.restorePurchases();
      
      if (customerInfo.entitlements.all['premium']?.isActive == true) {

        final uid = authStateManager.userId;
        if (uid != null) {
          final proUntil = DateTime.now().add(const Duration(days: 365));
          await prefsProvider.updateProStatus(uid: uid, proUntil: proUntil);
        }

        if (mounted) {
          // Navigate to post-subscription screen for restored purchases too
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const PostSubscriptionScreen(),
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
        title: const Text('Annoyed Premium'),
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
                    widget.message != null ? 'Subscribe to Continue' : 'Upgrade to Premium',
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
                    icon: Icons.auto_awesome,
                    title: '5x More AI Usage',
                    subtitle: '\$0.50/month limit vs \$0.10 for free users',
                  ),
                  _FeatureTile(
                    icon: Icons.psychology,
                    title: 'More AI Coaching',
                    subtitle: 'Generate more personalized coaching insights',
                  ),
                  _FeatureTile(
                    icon: Icons.analytics,
                    title: 'More AI Analysis',
                    subtitle: 'Categorize and analyze more annoyances',
                  ),
                  _FeatureTile(
                    icon: Icons.lightbulb,
                    title: 'More AI Suggestions',
                    subtitle: 'Get more actionable suggestions for your patterns',
                  ),
                  _FeatureTile(
                    icon: Icons.support_agent,
                    title: 'Priority Support',
                    subtitle: 'Fast response to questions and issues',
                  ),

                  const SizedBox(height: 32),

                  // Pricing
                  if (_products.isNotEmpty) ...[
                    ...(_products.map((product) {
                      final isAnnual = product.identifier.contains('annual');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ProductCard(
                          product: product,
                          isRecommended: isAnnual,
                          onTap: () => _purchaseProduct(product),
                        ),
                      );
                    })),
                  ] else ...[
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            const Text(
                              'Unable to load subscription options',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            if (_errorDetails != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _errorDetails!,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ] else ...[
                              Text(
                                'Check console logs for details',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                              const SizedBox(height: 12),
                            ],
                            ElevatedButton(
                              onPressed: _loadProducts,
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
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

class _ProductCard extends StatelessWidget {
  final StoreProduct product;
  final bool isRecommended;
  final VoidCallback onTap;

  const _ProductCard({
    required this.product,
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
              ? const Color(0xFF0F766E).withValues(alpha: 0.1)
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
                    product.title,
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
              product.priceString,
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







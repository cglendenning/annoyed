import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../providers/auth_state_manager.dart';
import '../services/firebase_service.dart';
import '../services/analytics_service.dart';
import '../utils/app_colors.dart';
import 'about_screen.dart';
import 'terms_screen.dart';
import 'paywall_screen.dart';
import 'email_auth_screen.dart';
import 'subscription_status_screen.dart';
import 'how_it_works_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _analyticsEnabled = true;
  bool _isPremium = false;
  bool _loadingSubscription = true;
  
  @override
  void initState() {
    super.initState();
    _loadAnalyticsPreference();
    _checkSubscriptionStatus();
  }
  
  Future<void> _checkSubscriptionStatus() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      
      final hasActiveEntitlement = customerInfo.entitlements.all['premium']?.isActive == true;
      final hasActiveSub = customerInfo.activeSubscriptions.isNotEmpty;
      
      if (mounted) {
        setState(() {
          _isPremium = hasActiveEntitlement || hasActiveSub;
          _loadingSubscription = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingSubscription = false;
        });
      }
    }
  }
  
  Future<void> _loadAnalyticsPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _analyticsEnabled = prefs.getBool('analytics_enabled') ?? true;
    });
  }
  
  Future<void> _saveAnalyticsPreference(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('analytics_enabled', enabled);
    if (enabled) {
      await AnalyticsService.logEvent('analytics_enabled');
    }
  }
  
  Future<void> _exportData() async {
    debugPrint('[Settings] Export data started');
    final authStateManager = Provider.of<AuthStateManager>(context, listen: false);
    
    debugPrint('[Settings] Auth status: ${authStateManager.isAuthenticated}, UID: ${authStateManager.userId}');
    
    if (!authStateManager.isAuthenticated) {
      debugPrint('[Settings] User not authenticated, showing error');
      _showErrorDialog(
        'Sign In Required',
        'You must be signed in to export your data.',
      );
      return;
    }
    
    // Show loading
    debugPrint('[Settings] Showing loading dialog');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Exporting data...',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
    
    try {
      final uid = authStateManager.userId!;
      debugPrint('[Settings] Fetching data for uid: $uid');
      
      // Fetch all user data
      final annoyances = await FirebaseService.getUserAnnoyances(uid);
      debugPrint('[Settings] Fetched ${annoyances.length} annoyances');
      final coachings = await FirebaseService.getAllCoachings(uid: uid);
      debugPrint('[Settings] Fetched ${coachings.length} coachings');
      
      // Format as JSON - convert all Timestamps to strings
      final exportData = {
        'export_date': DateTime.now().toIso8601String(),
        'user_id': uid,
        'annoyances': annoyances.map((a) => {
          'id': a.id,
          'timestamp': a.timestamp.toIso8601String(),
          'transcript': a.transcript,
          'category': a.category,
          'trigger': a.trigger,
        }).toList(),
        'coachings': coachings.map((coaching) {
          final converted = Map<String, dynamic>.from(coaching);
          // Convert Firestore Timestamps to ISO strings
          if (converted['ts'] != null) {
            final ts = converted['ts'];
            if (ts is DateTime) {
              converted['ts'] = ts.toIso8601String();
            } else {
              converted['ts'] = ts.toDate().toIso8601String();
            }
          }
          if (converted['timestamp'] != null) {
            final timestamp = converted['timestamp'];
            if (timestamp is DateTime) {
              converted['timestamp'] = timestamp.toIso8601String();
            } else {
              converted['timestamp'] = timestamp.toDate().toIso8601String();
            }
          }
          return converted;
        }).toList(),
      };
      
      if (!mounted) return;
      
      debugPrint('[Settings] Data fetched successfully, copying to clipboard');
      
      // Format and copy to clipboard
      final jsonString = const JsonEncoder.withIndent('  ').convert(exportData);
      await Clipboard.setData(ClipboardData(text: jsonString));
      
      debugPrint('[Settings] Data copied, closing loading');
      Navigator.of(context).pop(); // Close loading
      
      if (!mounted) return;
      
      debugPrint('[Settings] Showing success dialog');
      
      // Platform-specific paste instructions
      final pasteInstructions = Platform.isIOS
          ? 'Open the Notes app (or any other app)\n\n'
            '1. Tap and hold in the text area\n'
            '2. Tap "Paste" from the menu\n'
            '3. Your data will appear as formatted JSON'
          : 'Open any text app (Notes, Keep, etc.)\n\n'
            '1. Long press in the text area\n'
            '2. Tap "Paste" from the menu\n'
            '3. Your data will appear as formatted JSON';
      
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 32,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Data Exported!',
                  style: TextStyle(fontSize: 20),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory, color: Colors.green, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${annoyances.length} annoyances and ${coachings.length} coachings copied to clipboard',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'How to use:',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                pasteInstructions,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.info_outline, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Data is in JSON format - perfect for importing or sharing',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('[Settings] Export error: $e');
      if (mounted) {
        Navigator.of(context).pop(); // Close loading
        _showErrorDialog('Export Failed', 'Unable to export data: ${e.toString()}');
      }
    }
    debugPrint('[Settings] Export data completed');
  }
  
  Future<void> _deleteAllData() async {
    final authStateManager = Provider.of<AuthStateManager>(context, listen: false);
    
    // Check if user is signed in
    if (!authStateManager.isAuthenticated) {
      if (mounted) {
        _showErrorDialog(
          'Sign In Required',
          'You must be signed in to delete data. Please sign up or sign in first to manage your data.',
        );
      }
      return;
    }
    
    // Show confirmation dialog with text input requirement
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        final confirmTextController = TextEditingController();
        bool isValid = false;
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Delete All My Data'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'This will permanently delete:\n\n'
                      '• Your account and authentication\n'
                      '• All annoyances and recordings\n'
                      '• All coaching and suggestions\n'
                      '• All preferences and settings\n'
                      '• Everything from Firebase\n'
                      '• All local data on this device\n\n'
                      'This action cannot be undone and complies with GDPR "right to be forgotten."\n\n',
                    ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade300),
                      ),
                      child: const Text(
                        'Type "delete my data" below to confirm:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmTextController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'delete my data',
                        border: const OutlineInputBorder(),
                        errorText: confirmTextController.text.isNotEmpty && !isValid
                            ? 'Must match exactly'
                            : null,
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          isValid = value.trim().toLowerCase() == 'delete my data';
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isValid
                      ? () => Navigator.of(context).pop(true)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: const Text('Delete Everything'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm == true) {
      // Haptic feedback for destructive action
      HapticFeedback.heavyImpact();
      
      // Show loading dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }
      
      try {
        debugPrint('[Settings] Calling deleteAccount');
        
        // First, try to delete the account
        try {
          await authStateManager.deleteAccount();
        } on firebase_auth.FirebaseAuthException catch (e) {
          if (e.code == 'requires-recent-login') {
            debugPrint('[Settings] Requires recent login, prompting for password');
            
            // Close loading dialog
            if (mounted) Navigator.of(context).pop();
            
            // Prompt for password to re-authenticate
            final password = await showDialog<String>(
              context: context,
              barrierDismissible: false,
              builder: (context) {
                final passwordController = TextEditingController();
                return AlertDialog(
                  title: const Text('Confirm Password'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'For security, please enter your password to confirm account deletion.',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        autofocus: true,
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(passwordController.text),
                      child: const Text('Confirm'),
                    ),
                  ],
                );
              },
            );
            
            if (password == null || password.isEmpty) {
              // User cancelled
              return;
            }
            
            // Show loading again
            if (mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => Center(
                  child: Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text(
                          'Deleting account...',
                          style: TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }
            
            // Re-authenticate and try again
            await authStateManager.reauthenticateWithPassword(password);
            await authStateManager.deleteAccount();
          } else {
            rethrow;
          }
        }
        
        debugPrint('[Settings] deleteAccount completed successfully');
        
        // Reset onboarding flags so user sees onboarding on next launch
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('onboarding_completed');
        await prefs.remove('has_ever_signed_in_with_email');
        debugPrint('[Settings] Cleared onboarding flags');

        if (!mounted) return;
        
        Navigator.of(context).pop(); // Close loading dialog
        
        debugPrint('[Settings] Showing success dialog');
        // Show success dialog
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_outline,
                    color: Colors.green.shade700,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Data Deleted',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'All your data has been permanently deleted from our systems.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  debugPrint('[Settings] User confirmed deletion, navigating to root');
                  Navigator.of(context).pop(); // Close success dialog
                  // Navigate to root - app will restart with onboarding
                  Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          
          // Parse error message
          String errorMessage = 'Unable to delete data';
          String errorDetails = e.toString();
          
          if (errorDetails.contains('permission-denied')) {
            errorMessage = 'Permission Denied';
            errorDetails = 'You may need to sign in again to delete your data. Please try signing out and signing back in.';
          } else if (errorDetails.contains('network')) {
            errorMessage = 'Network Error';
            errorDetails = 'Please check your internet connection and try again.';
          } else if (errorDetails.contains('requires-recent-login')) {
            errorMessage = 'Authentication Required';
            errorDetails = 'For security, please sign out and sign back in, then try deleting again.';
          }
          
          _showErrorDialog(errorMessage, errorDetails);
        }
      }
    }
  }
  
  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.bolt_outlined,
                color: Colors.red.shade700,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle_outline,
                color: Colors.green.shade700,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 16),

          // Privacy
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Privacy',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Transcription uses your device\'s built-in speech engine. Audio never leaves your phone; only redacted text is sent for suggestions.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
          ),
          ListTile(
            title: const Text(
              'Delete all my data',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
            subtitle: const Text(
              'Remove everything from Firebase, this device, and everywhere',
              style: TextStyle(fontSize: 13),
            ),
            trailing: const Icon(Icons.delete_forever, color: Colors.red),
            onTap: _deleteAllData,
          ),

          const Divider(height: 32),

          // Subscription
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Subscription',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (_loadingSubscription)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (!_isPremium && !_loadingSubscription)
            ListTile(
              title: const Text('Upgrade to Premium'),
              subtitle: const Text('Unlock all premium features'),
              leading: const Icon(Icons.stars, color: Color(0xFF0F766E)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const PaywallScreen(),
                  ),
                );
                // Refresh subscription status when returning
                _checkSubscriptionStatus();
              },
            ),
          if (_isPremium && !_loadingSubscription)
            ListTile(
              title: const Text('Subscription Status'),
              subtitle: const Text('Manage your premium subscription'),
              leading: const Icon(Icons.verified, color: Colors.green),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const SubscriptionStatusScreen(),
                  ),
                );
                // Refresh subscription status when returning
                _checkSubscriptionStatus();
              },
            ),
          ListTile(
            title: const Text('Restore Purchases'),
            subtitle: const Text('Already subscribed? Restore your access'),
            leading: const Icon(Icons.download),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () async {
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );
              
              try {
                final customerInfo = await Purchases.restorePurchases();
                Navigator.pop(context); // Close loading dialog
                
                if (customerInfo.entitlements.all['premium']?.isActive == true) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Purchases restored!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('No active subscriptions found'),
                      ),
                    );
                  }
                }
              } catch (e) {
                Navigator.pop(context); // Close loading dialog
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Restore failed: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),

          const Divider(height: 32),

          // Account
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Account',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Consumer<AuthStateManager>(
            builder: (context, authManager, _) {
              if (authManager.isAuthenticated && authManager.userEmail != null) {
                return Column(
                  children: [
                    ListTile(
                      title: const Text('Email'),
                      subtitle: Text(authManager.userEmail!),
                      leading: const Icon(Icons.email, color: AppColors.primaryTeal),
                    ),
                    ListTile(
                      title: const Text('Sign Out'),
                      leading: const Icon(Icons.logout, color: Colors.orange),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Sign Out'),
                            content: const Text('Are you sure you want to sign out?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: const Text('Sign Out'),
                              ),
                            ],
                          ),
                        );
                        
                        if (confirm == true && mounted) {
                          await authManager.signOut();
                          // AuthGate will automatically show the right screen
                          // No manual navigation needed!
                        }
                      },
                    ),
                  ],
                );
              } else if (authManager.isAuthenticated) {
                return ListTile(
                  title: const Text('Sign In'),
                  subtitle: const Text('Sign up or sign in to save your data'),
                  leading: const Icon(Icons.login, color: AppColors.primaryTeal),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const EmailAuthScreen(
                          initialMode: AuthMode.signIn,
                        ),
                      ),
                    );
                  },
                );
              } else {
                return const SizedBox.shrink();
              }
            },
          ),

          const Divider(height: 32),

          // Data & Privacy
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Data & Privacy',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            title: const Text('Export My Data'),
            subtitle: const Text('Download all your data in JSON format'),
            leading: const Icon(Icons.download),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _exportData,
          ),
          Consumer<AuthStateManager>(
            builder: (context, authProvider, _) {
              return SwitchListTile(
                title: const Text('Analytics'),
                subtitle: const Text('Help us improve the app'),
                secondary: const Icon(Icons.analytics_outlined),
                value: _analyticsEnabled,
                onChanged: (value) {
                  setState(() {
                    _analyticsEnabled = value;
                  });
                  _saveAnalyticsPreference(value);
                },
              );
            },
          ),

          const Divider(height: 32),

          // About
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'About',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const ListTile(
            title: Text('Version'),
            trailing: Text('1.0.0'),
          ),
          ListTile(
            title: const Text('How It Works'),
            subtitle: const Text('Learn about categories, coaching, and more'),
            leading: const Icon(Icons.school, color: AppColors.primaryTeal),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const HowItWorksScreen(),
                ),
              );
            },
          ),
          ListTile(
            title: const Text('About Coach Craig'),
            leading: const Icon(Icons.person),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const AboutScreen(),
                ),
              );
            },
          ),
          ListTile(
            title: const Text('Terms of Service'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const TermsScreen(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}




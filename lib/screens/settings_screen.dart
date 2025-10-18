import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../providers/auth_provider.dart';
import '../services/firebase_service.dart';
import '../services/analytics_service.dart';
import 'about_screen.dart';
import 'terms_screen.dart';
import 'paywall_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<void> _resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Onboarding reset. Restart the app to see it again.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteAllData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Check if user is signed in
    if (!authProvider.isAuthenticated) {
      if (mounted) {
        _showErrorDialog(
          'Sign In Required',
          'You must be signed in to delete data. Please sign up or sign in first to manage your data.',
        );
      }
      return;
    }
    
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All My Data'),
        content: const Text(
          'This will permanently delete:\n\n'
          '• Your account and authentication\n'
          '• All annoyances and recordings\n'
          '• All coaching and suggestions\n'
          '• All preferences and settings\n'
          '• Everything from Firebase\n'
          '• All local data on this device\n\n'
          'This action cannot be undone and complies with GDPR "right to be forgotten."',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );

    if (confirm == true) {
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
        // This deletes everything - account, data, etc.
        await authProvider.deleteAccount();
        
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          _showSuccessDialog(
            'Data Deleted',
            'All your data has been permanently deleted from our systems.',
          );
        }
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
          ListTile(
            title: const Text('Upgrade to Pro'),
            subtitle: const Text('Unlock all premium features'),
            leading: const Icon(Icons.stars, color: Color(0xFF0F766E)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const PaywallScreen(),
                ),
              );
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
                
                if (customerInfo.entitlements.all['pro']?.isActive == true) {
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
          Consumer<AuthProvider>(
            builder: (context, authProvider, _) {
              if (authProvider.isAuthenticated && authProvider.userEmail != null) {
                return Column(
                  children: [
                    ListTile(
                      title: const Text('Email'),
                      subtitle: Text(authProvider.userEmail!),
                      leading: const Icon(Icons.email),
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
                          await authProvider.signOut();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Signed out successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ],
                );
              } else if (authProvider.isAuthenticated) {
                return ListTile(
                  title: const Text('Anonymous User'),
                  subtitle: const Text('Sign up to save your data'),
                  leading: const Icon(Icons.person_outline),
                );
              } else {
                return const SizedBox.shrink();
              }
            },
          ),

          const Divider(height: 32),

          // Debug
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'Debug',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            title: const Text('Reset Onboarding'),
            subtitle: const Text('See the tutorial and permission screens again'),
            trailing: const Icon(Icons.refresh),
            onTap: _resetOnboarding,
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




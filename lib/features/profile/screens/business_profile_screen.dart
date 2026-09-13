import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/billing_service.dart';

class BusinessProfileScreen extends StatefulWidget {
  const BusinessProfileScreen({super.key});

  @override
  State<BusinessProfileScreen> createState() => _BusinessProfileScreenState();
}

class _BusinessProfileScreenState extends State<BusinessProfileScreen> {
  final _companyNameController = TextEditingController();
  final _rcNumberController = TextEditingController();
  final _tinController = TextEditingController();
  final _addressController = TextEditingController();
  final _industryController = TextEditingController();
  
  String? _logoPath;
  bool _vaultLockEnabled = false;
  bool _biometricsEnabled = false;
  bool _isPremium = false;
  int _cacCredits = 0;
  int _aiCredits = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final billing = BillingService();
    final isPrem = await billing.isPremium();
    final credits = await billing.getCredits();

    setState(() {
      _companyNameController.text = prefs.getString('companyName') ?? '';
      _rcNumberController.text = prefs.getString('rcNumber') ?? '';
      _tinController.text = prefs.getString('tin') ?? '';
      _addressController.text = prefs.getString('address') ?? '';
      _industryController.text = prefs.getString('industry') ?? '';
      _logoPath = prefs.getString('logoPath');
      _vaultLockEnabled = prefs.getBool('vault_lock_enabled') ?? false;
      _biometricsEnabled = prefs.getBool('biometrics_enabled') ?? false;
      _isPremium = isPrem;
      _cacCredits = credits['cac'] ?? 0;
      _aiCredits = credits['ai'] ?? 0;
      _isLoading = false;
    });
  }

  Future<void> _saveProfile() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('companyName', _companyNameController.text.trim());
    await prefs.setString('rcNumber', _rcNumberController.text.trim());
    await prefs.setString('tin', _tinController.text.trim());
    await prefs.setString('address', _addressController.text.trim());
    await prefs.setString('industry', _industryController.text.trim());
    
    if (_logoPath != null) {
      await prefs.setString('logoPath', _logoPath!);
    } else {
      await prefs.remove('logoPath');
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 10),
              Text('Business Profile Saved Successfully'),
            ],
          ),
          backgroundColor: AppTheme.primaryGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _pickLogo() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _logoPath = image.path;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick logo: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _removeLogo() async {
    setState(() {
      _logoPath = null;
    });
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _rcNumberController.dispose();
    _tinController.dispose();
    _addressController.dispose();
    _industryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Business Profile'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Company Details',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.navyBlue),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Save your business details here to automatically pre-fill legal documents, compliance forms, and add watermarks.',
                    style: TextStyle(color: AppTheme.textLight),
                  ),
                  const SizedBox(height: 28),
                  
                  // Company Logo Watermark Selector
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.5), width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: _logoPath != null && File(_logoPath!).existsSync()
                                    ? Image.file(
                                        File(_logoPath!),
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        color: Colors.grey.shade100,
                                        child: const Icon(
                                          Icons.business,
                                          size: 50,
                                          color: AppTheme.textLight,
                                        ),
                                      ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: _pickLogo,
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primaryGreen,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _logoPath != null ? 'Company Logo Loaded' : 'Add Company Logo',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.navyBlue),
                        ),
                        Text(
                          'Used for letterhead & document watermark',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                        if (_logoPath != null) ...[
                          const SizedBox(height: 4),
                          TextButton.icon(
                            onPressed: _removeLogo,
                            icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                            label: const Text('Remove Logo', style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  _buildTextField('Registered Company Name', _companyNameController, Icons.business),
                  const SizedBox(height: 16),
                  _buildTextField('Industry (e.g. Technology, Agriculture)', _industryController, Icons.category),
                  const SizedBox(height: 16),
                  _buildTextField('RC Number / BN Number', _rcNumberController, Icons.numbers),
                  const SizedBox(height: 16),
                  _buildTextField('Tax Identification Number (TIN)', _tinController, Icons.receipt_long),
                  const SizedBox(height: 16),
                  _buildTextField('Registered Address', _addressController, Icons.location_on, maxLines: 3),
                  
                  const SizedBox(height: 32),
                  const Text(
                    'Security & Access',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.navyBlue),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: SwitchListTile.adaptive(
                      title: const Text('Enable Document Vault Lock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.navyBlue)),
                      subtitle: const Text('Require a 4-digit PIN to access generated contracts.', style: TextStyle(fontSize: 12)),
                      secondary: const Icon(Icons.lock_outline, color: AppTheme.primaryGreen),
                      activeColor: AppTheme.primaryGreen,
                      value: _vaultLockEnabled,
                      onChanged: (val) async {
                        if (val) {
                          // Setup passcode
                          context.push('/passcode', extra: {
                            'isSetupMode': true,
                            'onSuccess': () async {
                              final navigator = Navigator.of(context);
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool('vault_lock_enabled', true);
                              if (!mounted) return;
                              setState(() {
                                _vaultLockEnabled = true;
                              });
                              navigator.pop(); // Close passcode screen
                            }
                          });
                        } else {
                          // Verify passcode to disable
                          context.push('/passcode', extra: {
                            'isSetupMode': false,
                            'onSuccess': () async {
                              final navigator = Navigator.of(context);
                              final prefs = await SharedPreferences.getInstance();
                              await prefs.setBool('vault_lock_enabled', false);
                              if (!mounted) return;
                              setState(() {
                                _vaultLockEnabled = false;
                              });
                              navigator.pop(); // Close passcode screen
                            }
                          });
                        }
                      },
                    ),
                  ),
                  if (_vaultLockEnabled) ...[
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: SwitchListTile.adaptive(
                        title: const Text('Enable Biometric Unlock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.navyBlue)),
                        subtitle: const Text('Use fingerprint or Face ID to unlock your document vault.', style: TextStyle(fontSize: 12)),
                        secondary: const Icon(Icons.fingerprint, color: AppTheme.primaryGreen),
                        activeColor: AppTheme.primaryGreen,
                        value: _biometricsEnabled,
                        onChanged: (val) async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('biometrics_enabled', val);
                          setState(() {
                            _biometricsEnabled = val;
                          });
                        },
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),
                  const Text(
                    'Billing & Subscriptions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.navyBlue),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.navyBlue, Color(0xFF0A3C6E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.navyBlue.withOpacity(0.25),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: Plan Status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _isPremium ? Icons.workspace_premium : Icons.stars,
                                  color: _isPremium ? AppTheme.accentYellow : Colors.white60,
                                  size: 28,
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isPremium ? 'Kompli Premium' : 'Kompli Free Trial',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      _isPremium ? 'Unlimited Docs & E-Sign' : 'Limited Free Access',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.6),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _isPremium ? AppTheme.accentYellow.withOpacity(0.2) : Colors.white10,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _isPremium ? AppTheme.accentYellow : Colors.white30,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _isPremium ? 'ACTIVE' : 'FREE',
                                style: TextStyle(
                                  color: _isPremium ? AppTheme.accentYellow : Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: Colors.white24, height: 1),
                        const SizedBox(height: 20),

                        // Credits Display Section
                        const Text(
                          'REMAINING CREDITS',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            // CAC Credits
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Icon(Icons.search_outlined, color: AppTheme.accentYellow, size: 18),
                                        Text(
                                          '$_cacCredits',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'CAC Lookups',
                                      style: TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // AI Credits
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Icon(Icons.psychology_outlined, color: AppTheme.accentYellow, size: 18),
                                        Text(
                                          '$_aiCredits',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'AI Credits',
                                      style: TextStyle(color: Colors.white70, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Actions/Purchase triggers
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (!_isPremium)
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final success = await BillingService().simulatePurchasePremium();
                                  if (success) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Subscribed to Premium successfully!'),
                                          backgroundColor: AppTheme.primaryGreen,
                                        ),
                                      );
                                    }
                                    _loadProfile();
                                  }
                                },
                                icon: const Icon(Icons.workspace_premium, size: 16, color: AppTheme.navyBlue),
                                label: const Text(
                                  'Go Premium (₦5,000/mo)',
                                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.navyBlue),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentYellow,
                                  foregroundColor: AppTheme.navyBlue,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  minimumSize: Size.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              )
                            else
                              OutlinedButton.icon(
                                onPressed: () async {
                                  await BillingService().setMockPremium(false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Mock Premium subscription disabled.'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                  }
                                  _loadProfile();
                                },
                                icon: const Icon(Icons.remove_circle_outline, size: 16, color: Colors.white),
                                label: const Text(
                                  'Cancel Mock Sub',
                                  style: TextStyle(fontSize: 12, color: Colors.white),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white38),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  minimumSize: Size.zero,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ElevatedButton.icon(
                              onPressed: () async {
                                await BillingService().addCredits(10, 'cac');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Purchased 10 CAC Credits (₦2,500)'),
                                      backgroundColor: AppTheme.primaryGreen,
                                    ),
                                  );
                                }
                                _loadProfile();
                              },
                              icon: const Icon(Icons.add_circle_outline, size: 16, color: Colors.white),
                              label: const Text(
                                '+10 CAC (₦2,500)',
                                style: TextStyle(fontSize: 12, color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white24,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () async {
                                await BillingService().addCredits(10, 'ai');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Purchased 10 AI Credits (₦1,500)'),
                                      backgroundColor: AppTheme.primaryGreen,
                                    ),
                                  );
                                }
                                _loadProfile();
                              },
                              icon: const Icon(Icons.add_circle_outline, size: 16, color: Colors.white),
                              label: const Text(
                                '+10 AI (₦1,500)',
                                style: TextStyle(fontSize: 12, color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white24,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saveProfile,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Save Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => context.push('/policies'),
                      icon: const Icon(Icons.privacy_tip_outlined, color: AppTheme.primaryGreen),
                      label: const Text(
                        'App Privacy Policy & Terms of Service',
                        style: TextStyle(
                          color: AppTheme.primaryGreen,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Log Out'),
                            content: const Text('Are you sure you want to log out of Kompli?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Log Out', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await FirebaseAuth.instance.signOut();
                          if (context.mounted) {
                            context.go('/login');
                          }
                        }
                      },
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text(
                        'Log Out of Account',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Built by Armmy Tech LTD',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primaryGreen),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
        ),
      ),
    );
  }
}

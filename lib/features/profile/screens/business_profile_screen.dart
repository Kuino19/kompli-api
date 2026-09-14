import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
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
              Icon(Icons.check_circle, color: Colors.black),
              SizedBox(width: 10),
              Text('Business Profile Saved Successfully',
                  style: TextStyle(
                      color: Colors.black, fontWeight: FontWeight.bold)),
            ],
          ),
          backgroundColor: const Color(0xFF00E676),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      backgroundColor: const Color(0xFF090D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1424),
        elevation: 0,
        title: const Text('Business Profile',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Company Details',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Save your business details here to automatically pre-fill legal documents, compliance forms, and add watermarks.',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
                  ),
                  const SizedBox(height: 28),

                  // Company Logo Watermark Selector
                  Center(
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 110,
                              height: 110,
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D1424),
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: const Color(0xFF00E676), width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF00E676)
                                        .withValues(alpha: 0.15),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: _logoPath != null &&
                                        File(_logoPath!).existsSync()
                                    ? Image.file(
                                        File(_logoPath!),
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        color: const Color(0xFF0D1424),
                                        child: const Icon(
                                          Icons.business,
                                          size: 45,
                                          color: Color(0xFF00E676),
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
                                    color: Color(0xFF00E676),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt,
                                    color: Colors.black,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _logoPath != null
                              ? 'Company Logo Loaded'
                              : 'Add Company Logo',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.white),
                        ),
                        Text(
                          'Used for letterhead & document watermark',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.5)),
                        ),
                        if (_logoPath != null) ...[
                          const SizedBox(height: 4),
                          TextButton.icon(
                            onPressed: _removeLogo,
                            icon: const Icon(Icons.delete_outline,
                                size: 16, color: Colors.redAccent),
                            label: const Text('Remove Logo',
                                style: TextStyle(
                                    color: Colors.redAccent, fontSize: 13)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  _buildTextField('Registered Company Name',
                      _companyNameController, Icons.business),
                  const SizedBox(height: 16),
                  _buildTextField(
                      'Industry (e.g. Technology, Agriculture)',
                      _industryController,
                      Icons.category),
                  const SizedBox(height: 16),
                  _buildTextField(
                      'RC Number / BN Number', _rcNumberController, Icons.numbers),
                  const SizedBox(height: 16),
                  _buildTextField('Tax Identification Number (TIN)',
                      _tinController, Icons.receipt_long),
                  const SizedBox(height: 16),
                  _buildTextField(
                      'Registered Address', _addressController, Icons.location_on,
                      maxLines: 3),

                  const SizedBox(height: 32),
                  const Text(
                    'Security & Access',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1424),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: SwitchListTile.adaptive(
                      title: const Text('Enable Document Vault Lock',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.white)),
                      subtitle: Text(
                          'Require a 4-digit PIN to access generated contracts.',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.6))),
                      secondary: const Icon(Icons.lock_outline,
                          color: Color(0xFF00E676)),
                      activeColor: const Color(0xFF00E676),
                      value: _vaultLockEnabled,
                      onChanged: (val) async {
                        if (val) {
                          context.push('/passcode', extra: {
                            'isSetupMode': true,
                            'onSuccess': () async {
                              final navigator = Navigator.of(context);
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setBool('vault_lock_enabled', true);
                              if (!mounted) return;
                              setState(() {
                                _vaultLockEnabled = true;
                              });
                              navigator.pop();
                            }
                          });
                        } else {
                          context.push('/passcode', extra: {
                            'isSetupMode': false,
                            'onSuccess': () async {
                              final navigator = Navigator.of(context);
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setBool('vault_lock_enabled', false);
                              if (!mounted) return;
                              setState(() {
                                _vaultLockEnabled = false;
                              });
                              navigator.pop();
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
                        color: const Color(0xFF0D1424),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: SwitchListTile.adaptive(
                        title: const Text('Enable Biometric Unlock',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.white)),
                        subtitle: Text(
                            'Use fingerprint or Face ID to unlock your document vault.',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.6))),
                        secondary: const Icon(Icons.fingerprint,
                            color: Color(0xFF00E676)),
                        activeColor: const Color(0xFF00E676),
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
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0D1424), Color(0xFF1E293B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _isPremium
                                      ? Icons.workspace_premium
                                      : Icons.stars,
                                  color: _isPremium
                                      ? const Color(0xFFFFB300)
                                      : const Color(0xFF00E676),
                                  size: 28,
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isPremium
                                          ? 'Kompli Premium'
                                          : 'Kompli Free Plan',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      _isPremium
                                          ? 'Unlimited Docs & E-Sign'
                                          : 'Free Standard Verification & AI',
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.6),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _isPremium
                                    ? const Color(0xFFFFB300)
                                        .withValues(alpha: 0.2)
                                    : const Color(0xFF00E676)
                                        .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _isPremium
                                      ? const Color(0xFFFFB300)
                                      : const Color(0xFF00E676),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                _isPremium ? 'ACTIVE' : 'FREE',
                                style: TextStyle(
                                  color: _isPremium
                                      ? const Color(0xFFFFB300)
                                      : const Color(0xFF00E676),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Divider(color: Colors.white10, height: 1),
                        const SizedBox(height: 20),
                        Text(
                          'REMAINING CREDITS',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.08)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Icon(Icons.search_outlined,
                                            color: Color(0xFF00E676), size: 18),
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
                                      style: TextStyle(
                                          color: Colors.white70, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color:
                                          Colors.white.withValues(alpha: 0.08)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Icon(Icons.psychology_outlined,
                                            color: Color(0xFF00E676), size: 18),
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
                                      style: TextStyle(
                                          color: Colors.white70, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (!_isPremium)
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final success = await BillingService()
                                      .simulatePurchasePremium();
                                  if (success) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Subscribed to Premium successfully!'),
                                          backgroundColor: Color(0xFF00E676),
                                        ),
                                      );
                                    }
                                    _loadProfile();
                                  }
                                },
                                icon: const Icon(Icons.workspace_premium,
                                    size: 16, color: Colors.black),
                                label: const Text(
                                  'Go Premium (₦5,000/mo)',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00E676),
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  minimumSize: Size.zero,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              )
                            else
                              OutlinedButton.icon(
                                onPressed: () async {
                                  await BillingService().setMockPremium(false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Mock Premium subscription disabled.'),
                                        backgroundColor: Colors.orange,
                                      ),
                                    );
                                  }
                                  _loadProfile();
                                },
                                icon: const Icon(Icons.remove_circle_outline,
                                    size: 16, color: Colors.white),
                                label: const Text(
                                  'Cancel Sub',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.white),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white38),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  minimumSize: Size.zero,
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ElevatedButton.icon(
                              onPressed: () async {
                                await BillingService().addCredits(10, 'cac');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Purchased 10 CAC Credits (₦2,500)'),
                                      backgroundColor: Color(0xFF00E676),
                                    ),
                                  );
                                }
                                _loadProfile();
                              },
                              icon: const Icon(Icons.add_circle_outline,
                                  size: 16, color: Colors.white),
                              label: const Text(
                                '+10 CAC (₦2,500)',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white10,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () async {
                                await BillingService().addCredits(10, 'ai');
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Purchased 10 AI Credits (₦1,500)'),
                                      backgroundColor: Color(0xFF00E676),
                                    ),
                                  );
                                }
                                _loadProfile();
                              },
                              icon: const Icon(Icons.add_circle_outline,
                                  size: 16, color: Colors.white),
                              label: const Text(
                                '+10 AI (₦1,500)',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white10,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8)),
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
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Save Profile',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => context.push('/policies'),
                      icon: const Icon(Icons.privacy_tip_outlined,
                          color: Color(0xFF00E676)),
                      label: const Text(
                        'App Privacy Policy & Terms of Service',
                        style: TextStyle(
                          color: Color(0xFF00E676),
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
                            backgroundColor: const Color(0xFF0D1424),
                            title: const Text('Log Out',
                                style: TextStyle(color: Colors.white)),
                            content: const Text(
                                'Are you sure you want to log out of Kompli?',
                                style: TextStyle(color: Colors.white70)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel',
                                    style: TextStyle(color: Colors.white54)),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.redAccent),
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Log Out',
                                    style: TextStyle(color: Colors.white)),
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
                      icon: const Icon(Icons.logout, color: Colors.redAccent),
                      label: const Text(
                        'Log Out of Account',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Built by Goanitech LTD',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.3),
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

  Widget _buildTextField(
      String label, TextEditingController controller, IconData icon,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        prefixIcon: Icon(icon, color: const Color(0xFF00E676)),
        filled: true,
        fillColor: const Color(0xFF0D1424),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF00E676), width: 2),
        ),
      ),
    );
  }
}

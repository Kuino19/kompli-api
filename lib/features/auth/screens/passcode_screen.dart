import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/theme/app_theme.dart';

class PasscodeScreen extends StatefulWidget {
  final bool isSetupMode;
  final VoidCallback onSuccess;

  const PasscodeScreen({
    super.key,
    required this.isSetupMode,
    required this.onSuccess,
  });

  @override
  State<PasscodeScreen> createState() => _PasscodeScreenState();
}

class _PasscodeScreenState extends State<PasscodeScreen> {
  final List<int> _pin = [];
  String _message = '';
  String? _firstPinAttempt;
  bool _isConfirming = false;
  String? _savedPin;
  bool _isLoading = true;
  bool _showBiometricButton = false;

  final LocalAuthentication _localAuth = LocalAuthentication();

  @override
  void initState() {
    super.initState();
    _loadSavedPin();
  }

  Future<void> _loadSavedPin() async {
    final prefs = await SharedPreferences.getInstance();
    final biometricsEnabled = prefs.getBool('biometrics_enabled') ?? false;
    
    setState(() {
      _savedPin = prefs.getString('vault_passcode');
      _message = widget.isSetupMode 
          ? 'Create a 4-digit Passcode' 
          : (_savedPin == null ? 'Set up a passcode to lock your vault' : 'Enter Passcode to Unlock Vault');
      _showBiometricButton = biometricsEnabled && !widget.isSetupMode && _savedPin != null;
      _isLoading = false;
    });

    if (_showBiometricButton) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _authenticateWithBiometrics();
      });
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      final bool canCheck = await _localAuth.canCheckBiometrics;
      final bool isSupported = await _localAuth.isDeviceSupported();
      if (!canCheck && !isSupported) return;

      final bool didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Unlock your Kompli document vault',
        persistAcrossBackgrounding: true,
      );

      if (didAuthenticate) {
        widget.onSuccess();
      }
    } catch (e) {
      debugPrint('Biometric authentication error: $e');
    }
  }

  void _onNumberPressed(int number) {
    if (_pin.length >= 4) return;

    setState(() {
      _pin.add(number);
    });

    if (_pin.length == 4) {
      // Small delay for UX feel
      Future.delayed(const Duration(milliseconds: 200), _processPin);
    }
  }

  void _onBackPressed() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin.removeLast();
    });
  }

  Future<void> _processPin() async {
    final enteredPin = _pin.join();
    final prefs = await SharedPreferences.getInstance();

    if (widget.isSetupMode || _savedPin == null) {
      // Setup Mode
      if (!_isConfirming) {
        setState(() {
          _firstPinAttempt = enteredPin;
          _isConfirming = true;
          _pin.clear();
          _message = 'Confirm your 4-digit Passcode';
        });
      } else {
        if (_firstPinAttempt == enteredPin) {
          await prefs.setString('vault_passcode', enteredPin);
          await prefs.setBool('vault_lock_enabled', true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Passcode enabled successfully!'),
                backgroundColor: AppTheme.primaryGreen,
              ),
            );
            widget.onSuccess();
          }
        } else {
          setState(() {
            _isConfirming = false;
            _firstPinAttempt = null;
            _pin.clear();
            _message = 'Passcodes did not match. Start over:';
          });
        }
      }
    } else {
      // Verification Mode
      if (_savedPin == enteredPin) {
        widget.onSuccess();
      } else {
        setState(() {
          _pin.clear();
          _message = 'Incorrect passcode. Try again:';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppTheme.navyBlue,
      body: SafeArea(
        child: Column(
          children: [
            // Close / Back button in top left
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0, top: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            // Header Logo/Lock Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline,
                color: AppTheme.accentYellow,
                size: 38,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              widget.isSetupMode ? 'Document Vault Lock' : 'Kompli Secure Vault',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ),
            const SizedBox(height: 40),

            // PIN Dots Indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final filled = index < _pin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: filled ? AppTheme.primaryGreen : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: filled ? AppTheme.primaryGreen : Colors.white.withOpacity(0.4),
                      width: 2,
                    ),
                  ),
                );
              }),
            ),
            const Spacer(),

            // Keypad
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildKeypadButton(1),
                      _buildKeypadButton(2),
                      _buildKeypadButton(3),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildKeypadButton(4),
                      _buildKeypadButton(5),
                      _buildKeypadButton(6),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildKeypadButton(7),
                      _buildKeypadButton(8),
                      _buildKeypadButton(9),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Biometric button (fingerprint) or Cancel text button in bottom left
                      SizedBox(
                        width: 70,
                        height: 70,
                        child: _showBiometricButton
                            ? IconButton(
                                icon: const Icon(Icons.fingerprint, color: Colors.white, size: 32),
                                onPressed: _authenticateWithBiometrics,
                              )
                            : TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: Colors.white60, fontSize: 13),
                                ),
                              ),
                      ),
                      _buildKeypadButton(0),
                      // Backspace Button
                      SizedBox(
                        width: 70,
                        height: 70,
                        child: IconButton(
                          icon: const Icon(Icons.backspace_outlined, color: Colors.white),
                          onPressed: _onBackPressed,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Built by Goanitech LTD',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.4),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }

  Widget _buildKeypadButton(int number) {
    return GestureDetector(
      onTap: () => _onNumberPressed(number),
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          number.toString(),
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

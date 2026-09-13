import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../../services/billing_service.dart';
import 'paystack_payment_screen.dart';

class PremiumSheet extends StatefulWidget {
  final String title;
  final String description;
  final String creditType; // 'cac' or 'ai'
  final VoidCallback onPurchaseSuccess;

  const PremiumSheet({
    super.key,
    this.title = 'Upgrade to Kompli Premium',
    required this.description,
    required this.creditType,
    required this.onPurchaseSuccess,
  });

  @override
  State<PremiumSheet> createState() => _PremiumSheetState();
}

class _PremiumSheetState extends State<PremiumSheet> {
  bool _isPurchasing = false;

  Future<void> _subscribePremium() async {
    setState(() => _isPurchasing = true);
    final email = FirebaseAuth.instance.currentUser?.email ?? 'user@kompli.ng';

    final result = await BillingService().initializeTransaction(
      email: email,
      amountKobo: 500000, // ₦5,000
      planType: 'premium_monthly',
    );

    if (!mounted) return;

    bool success = false;
    if (result != null && (result['authorization_url'] ?? '').isNotEmpty) {
      setState(() => _isPurchasing = false);
      final res = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaystackPaymentScreen(
            authorizationUrl: result['authorization_url']!,
            reference: result['reference']!,
            planType: 'premium_monthly',
          ),
        ),
      );
      success = res ?? false;
    } else {
      // Fallback mock mode
      success = await BillingService().simulatePurchasePremium();
      setState(() => _isPurchasing = false);
    }

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Welcome to Premium! Unlimited access unlocked.'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
      widget.onPurchaseSuccess();
      Navigator.pop(context);
    }
  }

  Future<void> _buyCreditPack() async {
    setState(() => _isPurchasing = true);
    final email = FirebaseAuth.instance.currentUser?.email ?? 'user@kompli.ng';
    final isCac = widget.creditType == 'cac';
    final amountKobo = isCac ? 250000 : 150000; // ₦2,500 or ₦1,500
    final planType = isCac ? 'cac_pack' : 'ai_pack';

    final result = await BillingService().initializeTransaction(
      email: email,
      amountKobo: amountKobo,
      planType: planType,
    );

    if (!mounted) return;

    bool success = false;
    if (result != null && (result['authorization_url'] ?? '').isNotEmpty) {
      setState(() => _isPurchasing = false);
      final res = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PaystackPaymentScreen(
            authorizationUrl: result['authorization_url']!,
            reference: result['reference']!,
            planType: planType,
          ),
        ),
      );
      success = res ?? false;
    } else {
      await BillingService().addCredits(10, widget.creditType);
      success = true;
      setState(() => _isPurchasing = false);
    }

    if (success && mounted) {
      final packName = isCac ? 'CAC Lookups' : 'AI generations';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added 10 $packName credits to your account!'),
          backgroundColor: AppTheme.primaryGreen,
        ),
      );
      widget.onPurchaseSuccess();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final packName = widget.creditType == 'cac' ? '10 CAC Lookup Credits' : '10 AI Document Credits';
    final price = widget.creditType == 'cac' ? '₦2,500' : '₦1,500';

    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.navyBlue,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Grab handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          // Crown Icon
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.accentYellow.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.workspace_premium,
                color: AppTheme.accentYellow,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 16),

          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),

          Text(
            widget.description,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),

          if (_isPurchasing)
            const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
          else ...[
            // Option 1: Subscribe Unlimited (₦5,000/mo)
            ElevatedButton(
              onPressed: _subscribePremium,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.star, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Subscribe Unlimited (₦5,000/mo)',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Option 2: Credit Pack
            OutlinedButton(
              onPressed: _buyCreditPack,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                'Buy $packName ($price)',
                style: const TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

void showPremiumUpgradeSheet(
  BuildContext context, {
  String title = 'Upgrade to Kompli Premium',
  required String description,
  required String creditType,
  required VoidCallback onPurchaseSuccess,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => PremiumSheet(
      title: title,
      description: description,
      creditType: creditType,
      onPurchaseSuccess: onPurchaseSuccess,
    ),
  );
}

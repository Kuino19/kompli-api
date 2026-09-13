import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/billing_service.dart';
import '../theme/app_theme.dart';

class PaystackPaymentScreen extends StatefulWidget {
  final String authorizationUrl;
  final String reference;
  final String planType;

  const PaystackPaymentScreen({
    super.key,
    required this.authorizationUrl,
    required this.reference,
    required this.planType,
  });

  @override
  State<PaystackPaymentScreen> createState() => _PaystackPaymentScreenState();
}

class _PaystackPaymentScreenState extends State<PaystackPaymentScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
            _checkUrl(url);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
            _checkUrl(url);
          },
          onNavigationRequest: (NavigationRequest request) {
            if (_checkUrl(request.url)) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  bool _checkUrl(String url) {
    // Paystack redirects to standard success/callback URLs or close triggers
    if (url.contains('standard/complete') ||
        url.contains('callback') ||
        url.contains('trxref=') ||
        url.contains('paystack.co/close')) {
      _verifyAndClose();
      return true;
    }
    return false;
  }

  Future<void> _verifyAndClose() async {
    if (_isVerifying) return;
    setState(() => _isVerifying = true);

    final verified = await BillingService().verifyTransaction(widget.reference);

    if (mounted) {
      Navigator.of(context).pop(verified);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Paystack Checkout', style: TextStyle(color: AppTheme.navyBlue, fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppTheme.navyBlue),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        actions: [
          if (_isVerifying)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryGreen),
            ),
        ],
      ),
    );
  }
}

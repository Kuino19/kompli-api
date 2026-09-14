import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/verification_service.dart';
import '../../../services/billing_service.dart';
import '../../../services/aml_service.dart';
import '../../../core/widgets/premium_sheet.dart';

class VerificationScreen extends StatefulWidget {
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _cacController = TextEditingController();
  final _tinController = TextEditingController();
  final _amlController = TextEditingController();

  bool _isCacLoading = false;
  bool _isTinLoading = false;
  bool _isAmlLoading = false;
  
  Map<String, dynamic>? _cacResult;
  Map<String, dynamic>? _tinResult;
  AmlScreeningResult? _amlResult;

  String? _cacError;
  String? _tinError;
  String? _amlError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _cacController.dispose();
    _tinController.dispose();
    _amlController.dispose();
    super.dispose();
  }

  Future<void> _verifyCAC() async {
    final billing = BillingService();
    final isPremiumUser = await billing.isPremium();
    final credits = await billing.getCredits();
    final cacCredits = credits['cac'] ?? 0;

    if (!isPremiumUser && cacCredits <= 0) {
      if (!mounted) return;
      showPremiumUpgradeSheet(
        context,
        title: 'CAC Public Registry Search Locked',
        description: 'You have used all your free business lookups. Subscribe to Premium for unlimited checks or buy a CAC lookup credit pack.',
        creditType: 'cac',
        onPurchaseSuccess: () {
          // Re-trigger verification
          _verifyCAC();
        },
      );
      return;
    }

    final query = _cacController.text.trim();
    if (query.isEmpty) {
      setState(() => _cacError = 'Please enter a company name or RC number');
      return;
    }

    setState(() {
      _isCacLoading = true;
      _cacResult = null;
      _cacError = null;
    });

    try {
      final res = await VerificationService().verifyCompany(query);
      if (!isPremiumUser) {
        await billing.consumeCacCredit();
      }
      FirebaseAnalytics.instance.logEvent(
        name: 'cac_verified',
        parameters: {'query': query, 'success': true},
      );
      setState(() {
        _cacResult = res;
        _isCacLoading = false;
      });
    } catch (e) {
      FirebaseAnalytics.instance.logEvent(
        name: 'cac_verified',
        parameters: {'query': query, 'success': false, 'error': e.toString()},
      );
      setState(() {
        _cacError = e.toString().replaceAll('Exception:', '').trim();
        _isCacLoading = false;
      });
    }
  }

  Future<void> _verifyTIN() async {
    final billing = BillingService();
    final isPremiumUser = await billing.isPremium();
    final credits = await billing.getCredits();
    final cacCredits = credits['cac'] ?? 0;

    if (!isPremiumUser && cacCredits <= 0) {
      if (!mounted) return;
      showPremiumUpgradeSheet(
        context,
        title: 'Taxpayer Lookup Locked',
        description: 'You have used all your free taxpayer lookups. Subscribe to Premium for unlimited checks or buy a lookup credit pack.',
        creditType: 'cac',
        onPurchaseSuccess: () {
          // Re-trigger verification
          _verifyTIN();
        },
      );
      return;
    }

    final query = _tinController.text.trim();
    if (query.isEmpty) {
      setState(() => _tinError = 'Please enter a Tax Identification Number (TIN)');
      return;
    }

    setState(() {
      _isTinLoading = true;
      _tinResult = null;
      _tinError = null;
    });

    try {
      final res = await VerificationService().verifyTin(query);
      if (!isPremiumUser) {
        await billing.consumeCacCredit();
      }
      FirebaseAnalytics.instance.logEvent(
        name: 'tin_verified',
        parameters: {'query': query, 'success': true},
      );
      setState(() {
        _tinResult = res;
        _isTinLoading = false;
      });
    } catch (e) {
      FirebaseAnalytics.instance.logEvent(
        name: 'tin_verified',
        parameters: {'query': query, 'success': false, 'error': e.toString()},
      );
      setState(() {
        _tinError = e.toString().replaceAll('Exception:', '').trim();
        _isTinLoading = false;
      });
    }
  }

  Future<void> _verifyAML() async {
    final query = _amlController.text.trim();
    if (query.isEmpty) {
      setState(() => _amlError = 'Please enter a person or director name to screen');
      return;
    }

    setState(() {
      _isAmlLoading = true;
      _amlResult = null;
      _amlError = null;
    });

    try {
      final res = await AmlService().screenEntity(query);
      FirebaseAnalytics.instance.logEvent(
        name: 'aml_screened',
        parameters: {'query': query, 'risk': res.riskLevel.name},
      );
      setState(() {
        _amlResult = res;
        _isAmlLoading = false;
      });
    } catch (e) {
      setState(() {
        _amlError = e.toString().replaceAll('Exception:', '').trim();
        _isAmlLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Verify Business & AML Info'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryGreen,
          unselectedLabelColor: AppTheme.textLight,
          indicatorColor: AppTheme.primaryGreen,
          tabs: const [
            Tab(icon: Icon(Icons.business), text: 'CAC Search'),
            Tab(icon: Icon(Icons.receipt_long), text: 'FIRS TIN'),
            Tab(icon: Icon(Icons.security), text: 'AML / NIGSAC'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCacTab(),
          _buildTinTab(),
          _buildAmlTab(),
        ],
      ),
    );
  }

  Widget _buildCacTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CAC Public Registry Search',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.navyBlue),
          ),
          const SizedBox(height: 8),
          const Text(
            'Verify registration status, RC number, incorporation date, and directors listed with the Corporate Affairs Commission.',
            style: TextStyle(fontSize: 13, color: AppTheme.textLight, height: 1.5),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _cacController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Flutterwave or RC1324832',
                    errorText: _cacError,
                    prefixIcon: const Icon(Icons.search, color: AppTheme.primaryGreen),
                  ),
                  onSubmitted: (_) => _verifyCAC(),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isCacLoading ? null : _verifyCAC,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isCacLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Search'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          if (_cacResult != null) FadeInUp(duration: const Duration(milliseconds: 400), child: _buildCacCertificate(_cacResult!)),
        ],
      ),
    );
  }

  Widget _buildTinTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'FIRS/JTB Taxpayer Lookup',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.navyBlue),
          ),
          const SizedBox(height: 8),
          const Text(
            'Check the status of a Tax Identification Number (TIN) and review current FIRS office registration details.',
            style: TextStyle(fontSize: 13, color: AppTheme.textLight, height: 1.5),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tinController,
                  decoration: InputDecoration(
                    hintText: 'Enter 10-digit TIN (e.g. 19384029)',
                    errorText: _tinError,
                    prefixIcon: const Icon(Icons.search, color: AppTheme.primaryGreen),
                  ),
                  onSubmitted: (_) => _verifyTIN(),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _isTinLoading ? null : _verifyTIN,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isTinLoading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Search'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          if (_tinResult != null) FadeInUp(duration: const Duration(milliseconds: 400), child: _buildTinCertificate(_tinResult!)),
        ],
      ),
    );
  }

  Widget _buildCacCertificate(Map<String, dynamic> result) {
    final data = result['data'] as Map<String, dynamic>;
    final directors = List<String>.from(data['directors'] ?? []);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFF9FFF9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryGreen.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stamp / Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryGreen.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      result['source'] ?? 'Verified Record',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryGreen, letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'FEDERAL REPUBLIC OF NIGERIA',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textLight, letterSpacing: 1),
                  ),
                ],
              ),
              const Icon(Icons.verified_user, color: AppTheme.primaryGreen, size: 44),
            ],
          ),
          const Divider(height: 32, thickness: 1),
          
          // Company Name
          Text(
            data['companyName'] ?? 'UNKNOWN COMPANY',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.navyBlue, height: 1.3),
          ),
          const SizedBox(height: 16),

          // Detail rows
          _certificateRow('Registration Number', data['rcNumber'] ?? 'N/A', Icons.tag),
          _certificateRow('Company Type', data['type'] ?? 'N/A', Icons.class_outlined),
          _certificateRow('Status', data['status'] ?? 'N/A', Icons.check_circle_outline, color: AppTheme.primaryGreen),
          _certificateRow('Incorporation Date', data['incorporationDate'] ?? 'N/A', Icons.calendar_today_outlined),
          _certificateRow('Registered Address', data['address'] ?? 'N/A', Icons.location_on_outlined),
          
          if (directors.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              'Listed Directors',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.navyBlue),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: directors.map((director) {
                return Chip(
                  avatar: const CircleAvatar(backgroundColor: AppTheme.primaryGreen, child: Icon(Icons.person, size: 12, color: Colors.white)),
                  label: Text(director, style: const TextStyle(fontSize: 12, color: AppTheme.navyBlue)),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.grey.shade200),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTinCertificate(Map<String, dynamic> result) {
    final data = result['data'] as Map<String, dynamic>;
    final isCompliant = data['isCompliant'] ?? false;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFFAF9FF)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF6C63FF).withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6C63FF).withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C63FF).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      result['source'] ?? 'Verified Tax Record',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF6C63FF), letterSpacing: 0.5),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'FEDERAL INLAND REVENUE SERVICE',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textLight, letterSpacing: 1),
                  ),
                ],
              ),
              const Icon(Icons.assignment_turned_in, color: Color(0xFF6C63FF), size: 44),
            ],
          ),
          const Divider(height: 32, thickness: 1),

          // Taxpayer Name
          Text(
            data['taxpayerName'] ?? 'UNKNOWN TAXPAYER',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.navyBlue, height: 1.3),
          ),
          const SizedBox(height: 16),

          _certificateRow('TIN Number', data['tin'] ?? 'N/A', Icons.vpn_key_outlined),
          _certificateRow('Tax Office', data['firsOffice'] ?? 'N/A', Icons.account_balance_outlined),
          _certificateRow('Registration Email', data['email'] ?? 'N/A', Icons.mail_outline),
          _certificateRow(
            'Tax Compliance Status', 
            isCompliant ? 'COMPLIANT & ACTIVE' : 'OUTSTANDING RETURNS', 
            Icons.verified_user_outlined, 
            color: isCompliant ? AppTheme.primaryGreen : Colors.redAccent
          ),
        ],
      ),
    );
  }

  Widget _certificateRow(String label, String value, IconData icon, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color ?? AppTheme.textLight),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: AppTheme.textLight, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13, 
                    fontWeight: FontWeight.bold, 
                    color: color ?? AppTheme.navyBlue,
                    height: 1.4
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmlTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AML & Sanctions Screening (NIGSAC + UN)',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.navyBlue),
          ),
          const SizedBox(height: 8),
          const Text(
            'Screen directors, beneficial owners, or entities against the Nigeria Sanctions List (NIGSAC under TPPA 2022) & UN Consolidated List.',
            style: TextStyle(fontSize: 13, color: AppTheme.textLight, height: 1.5),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amlController,
                  decoration: InputDecoration(
                    hintText: 'e.g. Director or Entity Name',
                    errorText: _amlError,
                    prefixIcon: const Icon(Icons.security, color: Color(0xFFFFB300)),
                  ),
                  onSubmitted: (_) => _verifyAML(),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                  ),
                  onPressed: _isAmlLoading ? null : _verifyAML,
                  child: _isAmlLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Screen AML'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_amlResult != null) ...[
            FadeInUp(
              duration: const Duration(milliseconds: 400),
              child: _buildAmlResultCard(_amlResult!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAmlResultCard(AmlScreeningResult res) {
    Color riskColor;
    String riskTitle;
    IconData riskIcon;

    switch (res.riskLevel) {
      case AmlRiskLevel.highRiskMatch:
        riskColor = Colors.redAccent;
        riskTitle = 'HIGH RISK — SANCTIONS MATCH DETECTED';
        riskIcon = Icons.report_problem;
        break;
      case AmlRiskLevel.possibleMatch:
        riskColor = const Color(0xFFFFB300);
        riskTitle = 'POSSIBLE MATCH — REVIEW REQUIRED';
        riskIcon = Icons.warning_amber_rounded;
        break;
      case AmlRiskLevel.clear:
      default:
        riskColor = AppTheme.primaryGreen;
        riskTitle = 'CLEAR — NO SANCTIONS MATCH DETECTED';
        riskIcon = Icons.verified_user;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: riskColor.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(riskIcon, color: riskColor, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  riskTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: riskColor,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: riskColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${res.similarityScore.toStringAsFixed(0)}% Score',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: riskColor,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Text(
            'Screened Query: ${res.queryName}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.navyBlue),
          ),
          if (res.matchedName != null) ...[
            const SizedBox(height: 6),
            Text(
              'Matched Entity: ${res.matchedName}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.redAccent),
            ),
            Text(
              'Database Source: ${res.listSource} (${res.designationCategory})',
              style: const TextStyle(fontSize: 12, color: AppTheme.textLight),
            ),
          ],
          const SizedBox(height: 16),
          const Text(
            'Statutory Obligations under TPPA 2022:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.navyBlue),
          ),
          const SizedBox(height: 8),
          ...res.legalObligations.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.arrow_right, size: 18, color: AppTheme.primaryGreen),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textLight, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (res.riskLevel != AmlRiskLevel.clear) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () {
                  context.push('/chat');
                },
                icon: const Icon(Icons.auto_awesome, color: Color(0xFF00E676), size: 18),
                label: const Text(
                  'Ask AI Assistant for NFIU STR Reporting Steps →',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

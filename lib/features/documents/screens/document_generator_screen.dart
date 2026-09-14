import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import '../../ai_assistant/services/ai_service.dart';
import '../../../services/billing_service.dart';
import '../../../core/widgets/premium_sheet.dart';

class DocumentGeneratorScreen extends ConsumerStatefulWidget {
  const DocumentGeneratorScreen({super.key});

  @override
  ConsumerState<DocumentGeneratorScreen> createState() =>
      _DocumentGeneratorScreenState();
}

class _DocumentGeneratorScreenState
    extends ConsumerState<DocumentGeneratorScreen> {
  String _selectedTemplate = 'Non-Disclosure Agreement (NDA)';

  final List<Map<String, dynamic>> _templates = [
    {
      'name': 'Non-Disclosure Agreement (NDA)',
      'icon': Icons.lock_outline,
      'color': const Color(0xFF6C63FF),
      'fields': ['Party B (Other Party)', 'Purpose / Subject of Disclosure'],
    },
    {
      'name': 'Employment Contract',
      'icon': Icons.badge_outlined,
      'color': const Color(0xFF00E676),
      'fields': [
        'Employee Full Name',
        'Job Title',
        'Monthly Salary (₦)',
        'Start Date'
      ],
    },
    {
      'name': 'Commercial Lease Agreement',
      'icon': Icons.home_work_outlined,
      'color': const Color(0xFF1ABC9C),
      'fields': [
        'Landlord Name',
        'Property Address',
        'Lease Duration',
        'Annual Rent (₦)'
      ],
    },
    {
      'name': 'Board Resolution',
      'icon': Icons.gavel_outlined,
      'color': const Color(0xFF34495E),
      'fields': ['Meeting Date', 'Resolutions Approved'],
    },
    {
      'name': 'Vendor/Service Agreement',
      'icon': Icons.handshake_outlined,
      'color': const Color(0xFFE67E22),
      'fields': [
        'Vendor / Service Provider Name',
        'Services to be Rendered',
        'Contract Value (₦)'
      ],
    },
    {
      'name': 'Partnership Agreement',
      'icon': Icons.group_outlined,
      'color': const Color(0xFF2980B9),
      'fields': [
        'Partner Name',
        'Business Description',
        'Profit-Sharing Ratio (e.g. 50/50)'
      ],
    },
    {
      'name': 'SME Website Privacy Policy',
      'icon': Icons.security_outlined,
      'color': const Color(0xFF8E44AD),
      'fields': [
        'Website/App URL',
        'Contact Email',
        'User Data Collected (e.g. name, email, cookies)',
        'Hosting Location/Country'
      ],
    },
    {
      'name': 'SME Terms & Conditions',
      'icon': Icons.description_outlined,
      'color': const Color(0xFFD35400),
      'fields': [
        'Website/App URL',
        'Contact Email',
        'Permitted Use Restrictions (e.g. no scraping, age 18+)',
        'Refund/Cancellation Policy (e.g. no refunds, 7 days)'
      ],
    },
    {
      'name': 'Custom (AI Generated)',
      'icon': Icons.auto_awesome,
      'color': const Color(0xFFFFB300),
      'fields': [],
    },
  ];

  final Map<String, TextEditingController> _fieldControllers = {};
  final TextEditingController _partyAController = TextEditingController();
  final TextEditingController _customPromptController =
      TextEditingController();
  bool _isGenerating = false;
  bool _hasProfileData = false;

  String _rcNumber = '';
  String _address = '';
  String _industry = '';

  Map<String, dynamic> get _currentTemplate =>
      _templates.firstWhere((t) => t['name'] == _selectedTemplate);

  @override
  void initState() {
    super.initState();
    _loadBusinessProfile();
    _initFieldControllers();
  }

  void _initFieldControllers() {
    for (final template in _templates) {
      for (final field in List<String>.from(template['fields'] as List)) {
        _fieldControllers.putIfAbsent(field, () => TextEditingController());
      }
    }
  }

  Future<void> _loadBusinessProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final companyName = prefs.getString('companyName') ?? '';
    final address = prefs.getString('address') ?? '';
    final rcNumber = prefs.getString('rcNumber') ?? '';
    final industry = prefs.getString('industry') ?? '';
    if (mounted) {
      setState(() {
        _partyAController.text = companyName;
        _hasProfileData = companyName.isNotEmpty;
        _rcNumber = rcNumber;
        _address = address;
        _industry = industry;
      });
    }
  }

  String _buildPrompt() {
    final template = _selectedTemplate;
    final partyA = _partyAController.text.isNotEmpty
        ? _partyAController.text
        : 'Party A';
    final rc = _rcNumber.isNotEmpty ? '(RC: $_rcNumber)' : '';
    final addr = _address.isNotEmpty ? ', Address: $_address' : '';
    final ind = _industry.isNotEmpty ? ', Industry: $_industry' : '';
    final companyContext = '$partyA $rc$addr$ind';

    if (template == 'Custom (AI Generated)') {
      return '''IMPORTANT: Output ONLY the legal document text. No greetings, no explanations, no preamble. Start directly with the document title in Markdown (# TITLE).

You are a senior Nigerian legal counsel. Draft a complete, formal, and legally sound legal document for a Nigerian SME.
Client context: ${_customPromptController.text}
Client company: $companyContext

Requirements:
- Apply Nigerian law (CAMA 2020, relevant Nigerian statutes)
- Include all standard clauses appropriate for this document type
- Use clear Markdown headings (##) and numbered clauses
- End with signature blocks
- Begin your response with the document title as a # heading. Nothing before it.''';
    }

    final fields = List<String>.from(_currentTemplate['fields'] as List);
    final fieldData = fields.map((f) {
      final val = _fieldControllers[f]?.text ?? '';
      return '- $f: ${val.isNotEmpty ? val : "[Not provided]"}';
    }).join('\n');

    final prompts = {
      'Non-Disclosure Agreement (NDA)': '''Draft a comprehensive Non-Disclosure Agreement (NDA) under Nigerian law for:
- Disclosing Party: $companyContext
$fieldData

Include: definitions, obligations, exclusions, term (2 years), remedies for breach, governing law (Nigeria), dispute resolution. Format with Markdown headings and numbered clauses. End with signature blocks.''',
      'Employment Contract': '''Draft a formal Employment Contract compliant with Nigerian Labour Act for:
- Employer: $companyContext
$fieldData

Include: appointment clause, duties, remuneration, leave entitlements (21 days annual), probation (3 months), termination notice (1 month), confidentiality, IP rights, pension (PENCOM compliance), governing law. Format with Markdown headings and numbered clauses. End with signature blocks.''',
      'Commercial Lease Agreement': '''Draft a Commercial Lease Agreement under Nigerian law (relevant state Tenancy Law, e.g. Lagos State Tenancy Law) for:
- Tenant: $companyContext
$fieldData

Include: description of property, lease term, rent payment terms, covenants of landlord (quiet enjoyment, structural repairs), covenants of tenant (rent payment, maintenance, no alterations, user clause), termination notice, dispute resolution (mediation/arbitration), governing law (Nigeria). Format with Markdown headings and numbered clauses. End with signature blocks.''',
      'Board Resolution': '''Draft a formal Board Resolution for a Nigerian Private Limited Company compliant with CAMA 2020:
- Company: $companyContext
$fieldData

Include: date of board meeting, board members present (directors), recitals, resolved clauses (e.g. to open bank account, appoint auditors, or execute agreement), authorization to execute, secretary signature block, director signature block. Format with Markdown headings and numbered clauses.''',
      'Vendor/Service Agreement': '''Draft a Vendor/Service Agreement under Nigerian law for:
- Client: $companyContext
$fieldData

Include: scope of services, payment terms (30 days), invoicing, warranties, liability cap, IP ownership, termination (30 days notice), confidentiality, force majeure, governing law (Nigeria). Format with Markdown headings and numbered clauses. End with signature blocks.''',
      'Partnership Agreement': '''Draft a formal Partnership Agreement under Nigerian law (Partnership Law) for:
- First Partner: $companyContext
$fieldData

Include: business purpose, capital contributions, profit/loss sharing, management roles, banking, dispute resolution (Lagos Multi-Door Courthouse or arbitration), dissolution procedure, exit clauses. Format with Markdown headings and numbered clauses. End with signature blocks.''',
      'SME Website Privacy Policy': '''Draft a comprehensive, professional Website and App Privacy Policy under Nigerian law, fully compliant with the Nigeria Data Protection Act (NDPA) 2023 for:
- Company/Platform Operator: $companyContext
$fieldData

Include: 
1. Introduction and Scope (mentioning NDPA 2023 compliance)
2. Personal Data We Collect (based on the fields: User Data Collected, Website/App URL)
3. Lawful Basis for Processing (Consent, Contractual Obligation, Legitimate Interest)
4. How We Use and Share Your Data
5. Data Retention, Storage and International Transfers (reference the Hosting Location/Country field)
6. Data Subject Rights (access, rectification, erasure, objection, lodge complaint with NDPC)
7. Security of Data (technical & organizational measures)
8. Cookies and Tracking Technologies
9. Contact Information (Contact Email)

Format with clear Markdown headings and numbered sections. No preamble or chat greeting, start directly with the document title.''',
      'SME Terms & Conditions': '''Draft a formal, comprehensive Website and Application Terms and Conditions (Terms of Use) under Nigerian law for:
- Company/Platform Operator: $companyContext
$fieldData

Include:
1. Agreement to Terms & Eligibility (minimum age, registration)
2. Permitted Use & Restrictions (reference the Permitted Use Restrictions field)
3. Intellectual Property Rights (ownership of content, logos)
4. Payments, Billing & Refunds (reference the Refund/Cancellation Policy field)
5. Disclaimer of Warranties & Limitation of Liability (under Nigerian law)
6. Indemnification
7. Termination of Use
8. Governing Law and Dispute Resolution (governed by laws of Nigeria, mediation/arbitration in Nigeria)
9. Contact Information (Contact Email)

Format with clear Markdown headings and numbered sections. No preamble or chat greeting, start directly with the document title.''',
    };

    return prompts[template] ?? 'Draft a legal document for $partyA.';
  }

  Future<void> _generateDocument() async {
    final billing = BillingService();
    final isPremiumUser = await billing.isPremium();
    final credits = await billing.getCredits();
    final aiCredits = credits['ai'] ?? 0;

    if (!isPremiumUser && aiCredits <= 0) {
      if (!mounted) return;
      showPremiumUpgradeSheet(
        context,
        title: 'AI Drafting Locked',
        description:
            'You have used all your free AI document drafts. Subscribe to Premium for unlimited generations or buy an AI credit pack.',
        creditType: 'ai',
        onPurchaseSuccess: () {
          _generateDocument();
        },
      );
      return;
    }

    if (_selectedTemplate == 'Custom (AI Generated)' &&
        _customPromptController.text.trim().isEmpty) {
      _showError('Please describe what you need drafted.');
      return;
    }

    final fields = List<String>.from(_currentTemplate['fields'] as List);
    if (_selectedTemplate != 'Custom (AI Generated)') {
      final emptyField = fields.firstWhere(
        (f) => (_fieldControllers[f]?.text ?? '').trim().isEmpty,
        orElse: () => '',
      );
      if (emptyField.isNotEmpty) {
        _showError('Please fill in: $emptyField');
        return;
      }
    }

    setState(() => _isGenerating = true);
    final aiService = ref.read(aiServiceProvider);

    try {
      final prompt = _buildPrompt();
      final response = await aiService.sendMessage(prompt);

      if (!mounted) return;
      setState(() => _isGenerating = false);

      if (response.startsWith('Both AI providers failed') ||
          response.startsWith('An error occurred')) {
        _showError(
          'Could not generate document. Please check your internet connection and try again.',
        );
        return;
      }

      if (response.startsWith('⚠️ **AI Rate Limit Exceeded**')) {
        _showError(response.replaceAll('⚠️ ', '').replaceAll('**', ''));
        return;
      }

      if (!isPremiumUser) {
        await billing.consumeAiCredit();
      }

      FirebaseAnalytics.instance.logEvent(
        name: 'document_generated',
        parameters: {'template': _selectedTemplate},
      );

      context.push('/document_preview', extra: {
        'title': _selectedTemplate,
        'content': response,
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isGenerating = false);
        _showError('Failed to generate document. Please try again.');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  void dispose() {
    _partyAController.dispose();
    _customPromptController.dispose();
    for (final c in _fieldControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCustom = _selectedTemplate == 'Custom (AI Generated)';
    final fields = List<String>.from(_currentTemplate['fields'] as List);
    final templateColor = _currentTemplate['color'] as Color;

    return Scaffold(
      backgroundColor: const Color(0xFF090D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1424),
        elevation: 0,
        title: const Text(
          'Generate Document',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Template Selector Cards
            FadeInDown(
              duration: const Duration(milliseconds: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select Document Type',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 100,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _templates.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final t = _templates[index];
                        final isSelected = _selectedTemplate == t['name'];
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedTemplate = t['name']),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 105,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (t['color'] as Color).withValues(alpha: 0.2)
                                  : const Color(0xFF0D1424),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? (t['color'] as Color)
                                    : Colors.white.withValues(alpha: 0.1),
                                width: isSelected ? 2 : 1,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: (t['color'] as Color)
                                            .withValues(alpha: 0.3),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      )
                                    ]
                                  : [],
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  t['icon'] as IconData,
                                  color: isSelected
                                      ? (t['color'] as Color)
                                      : Colors.white70,
                                  size: 26,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  (t['name'] as String).split(' ').first,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.white70,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // AI Badge
            FadeInUp(
              duration: const Duration(milliseconds: 400),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1424),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: templateColor.withValues(alpha: 0.4), width: 1.5),
                ),
                child: Row(
                  children: [
                    Icon(Icons.auto_awesome, color: templateColor, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isCustom
                            ? 'AI will draft a fully custom legal document based on your description'
                            : 'AI will generate a complete, Nigeria-law compliant $_selectedTemplate using your details',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Form Fields
            FadeInUp(
              delay: const Duration(milliseconds: 100),
              duration: const Duration(milliseconds: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isCustom) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Your Company Details',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.white),
                        ),
                        if (_hasProfileData)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00E676)
                                  .withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.check_circle,
                                    color: Color(0xFF00E676), size: 14),
                                SizedBox(width: 4),
                                Text(
                                  'Auto-filled from Profile',
                                  style: TextStyle(
                                    color: Color(0xFF00E676),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildField(
                      controller: _partyAController,
                      label: 'Your Company Name (auto-filled)',
                      icon: Icons.business,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _selectedTemplate.split(' ').first == 'Non'
                          ? 'Other Party Details'
                          : 'Contract Details',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    ...fields.asMap().entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _buildField(
                          controller: _fieldControllers[entry.value]!,
                          label: entry.value,
                          icon: _fieldIcon(entry.value),
                        ),
                      );
                    }),
                  ] else ...[
                    const Text('Describe your document',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Colors.white)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _customPromptController,
                      maxLines: 6,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText:
                            'e.g. A 6-month shop lease in Lagos between my company and Mr. Ade, ₦150,000/month rent, tenant pays utilities...',
                        hintStyle: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.4)),
                        filled: true,
                        fillColor: const Color(0xFF0D1424),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                              color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide:
                              const BorderSide(color: Color(0xFF00E676)),
                        ),
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Generate Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isGenerating ? null : _generateDocument,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _isGenerating
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.black, strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text('AI is drafting your document...',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.bold)),
                        ],
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome,
                              color: Colors.black, size: 20),
                          SizedBox(width: 10),
                          Text('Generate with AI',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 30),
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

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
        prefixIcon: Icon(icon, color: const Color(0xFF00E676), size: 20),
        filled: true,
        fillColor: const Color(0xFF0D1424),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFF00E676), width: 2),
        ),
      ),
    );
  }

  IconData _fieldIcon(String field) {
    final f = field.toLowerCase();
    if (f.contains('name') || f.contains('partner') || f.contains('employee')) {
      return Icons.person_outline;
    }
    if (f.contains('salary') || f.contains('value') || f.contains('₦')) {
      return Icons.payments_outlined;
    }
    if (f.contains('date')) return Icons.calendar_today_outlined;
    if (f.contains('title') || f.contains('job')) return Icons.work_outline;
    if (f.contains('address') || f.contains('location')) {
      return Icons.location_on_outlined;
    }
    if (f.contains('duration') || f.contains('term') || f.contains('period')) {
      return Icons.access_time_outlined;
    }
    if (f.contains('service') ||
        f.contains('purpose') ||
        f.contains('business')) {
      return Icons.description_outlined;
    }
    if (f.contains('ratio') || f.contains('profit'))
      return Icons.pie_chart_outline;
    return Icons.edit_outlined;
  }
}

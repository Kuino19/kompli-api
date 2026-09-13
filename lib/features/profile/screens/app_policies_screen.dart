import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class AppPoliciesScreen extends StatefulWidget {
  const AppPoliciesScreen({super.key});

  @override
  State<AppPoliciesScreen> createState() => _AppPoliciesScreenState();
}

class _AppPoliciesScreenState extends State<AppPoliciesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Policies & Terms'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.navyBlue,
          unselectedLabelColor: AppTheme.textLight,
          indicatorColor: AppTheme.primaryGreen,
          indicatorWeight: 3,
          tabs: const [
            Tab(
              icon: Icon(Icons.privacy_tip_outlined),
              text: 'Privacy Policy',
            ),
            Tab(
              icon: Icon(Icons.gavel_outlined),
              text: 'Terms of Service',
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Premium Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search policies...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.primaryGreen),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
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
            ),
          ),
          
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPrivacyPolicyTab(),
                _buildTermsOfServiceTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyPolicyTab() {
    final sections = [
      _PolicySection(
        title: '1. Introduction & Scope',
        content: 'Welcome to Kompli. We are committed to protecting the private data of your business and stakeholders. In compliance with the Nigeria Data Protection Act (NDPA) 2023, this Privacy Policy outlines how we collect, process, secure, and dispose of your information.',
      ),
      _PolicySection(
        title: '2. Local-First & Zero-Knowledge Architecture',
        content: 'Kompli operates primarily on a local-first storage model. Generated documents, signatures, business profile information, and passcodes are stored securely directly on your device\'s local storage using encrypted preferences. We do not upload your raw contracts or business identification documents to our servers unless you explicitly request cloud backup or sharing features.',
      ),
      _PolicySection(
        title: '3. Data Collection & Processing',
        content: 'When using Kompli, we collect and process the following information:\n• Business Profile Data: Company Name, Industry, RC/BN Number, TIN, and Address (used to pre-fill templates).\n• Electronic Signatures: Saved as local image assets to apply to PDFs.\n• Temporary AI Context: Text prompts and documents are temporarily sent to Gemini/Groq APIs for generating and customising documents. This data is not used to train the base models.',
      ),
      _PolicySection(
        title: '4. Compliance with NDPA 2023',
        content: 'In accordance with the Nigeria Data Protection Act (NDPA) 2023, we guarantee:\n• Consent: We only process business info that you voluntarily submit.\n• Security: Implementation of passcode lock mechanisms to protect saved contracts.\n• Data Minimisation: We only request and save information strictly necessary for document generation and compliance tracking.',
      ),
      _PolicySection(
        title: '5. Your Rights as a Data Subject',
        content: 'Under the NDPA 2023, you have the right to access, rectify, or request the erasure of your personal data. You can delete all your stored profile information and local documents at any time by clearing the application storage or resetting the profile settings in-app.',
      ),
      _PolicySection(
        title: '6. Updates to this Policy',
        content: 'We may revise this Privacy Policy periodically. We will notify you of any changes by updating the "Last Updated" date at the bottom of this page and posting a notification on the Dashboard.',
      ),
    ];

    final filteredSections = sections.where((sec) {
      return sec.title.toLowerCase().contains(_searchQuery) ||
          sec.content.toLowerCase().contains(_searchQuery);
    }).toList();

    return _buildPolicyList(
      title: 'Nigeria Data Protection Act (NDPA) 2023 Compliant',
      subtitle: 'Last Updated: June 11, 2026',
      badgeText: 'NDPA COMPLIANT',
      badgeColor: AppTheme.primaryGreen,
      sections: filteredSections,
    );
  }

  Widget _buildTermsOfServiceTab() {
    final sections = [
      _PolicySection(
        title: '1. Acceptance of Terms',
        content: 'By accessing or using the Kompli mobile application, you agree to comply with and be bound by these Terms of Service. If you do not agree, please do not use the app.',
      ),
      _PolicySection(
        title: '2. Description of Service & Legal Disclaimer',
        content: 'Kompli is an automated compliance management and document generator tool. The legal templates, NDA generators, website terms, and compliance trackers provided are for educational and business guidance purposes only. Kompli is NOT a law firm and does NOT provide formal legal advice. Use of these materials does not establish an attorney-client relationship. You are encouraged to review generated agreements with a qualified legal practitioner in Nigeria before final execution.',
      ),
      _PolicySection(
        title: '3. Passcode Lock & Security Responsibility',
        content: 'You are solely responsible for maintaining the confidentiality of your Vault Passcode (PIN). If you enable passcode protection, ensure you choose a secure code. Kompli is not responsible for unauthorised access to your device or local database due to weak security practices.',
      ),
      _PolicySection(
        title: '4. Third-Party Integrations',
        content: 'Kompli links with external APIs (including Mono, Dojah, Gemini, and Groq) to provide company verification and AI assistance. While we make every effort to ensure sandbox and live services are reliable, we are not liable for downtime, API rate limit restrictions, or inaccurate registry responses from the CAC or FIRS.',
      ),
      _PolicySection(
        title: '5. Limitation of Liability',
        content: 'To the maximum extent permitted by Nigerian law, Kompli shall not be liable for any direct, indirect, incidental, or consequential damages resulting from the use or inability to use the application, including document generation errors, missed regulatory deadlines, or data loss.',
      ),
      _PolicySection(
        title: '6. Governing Law',
        content: 'These Terms of Service are governed by and construed in accordance with the laws of the Federal Republic of Nigeria. Any disputes arising under these terms shall be subject to the exclusive jurisdiction of the competent courts of Nigeria.',
      ),
    ];

    final filteredSections = sections.where((sec) {
      return sec.title.toLowerCase().contains(_searchQuery) ||
          sec.content.toLowerCase().contains(_searchQuery);
    }).toList();

    return _buildPolicyList(
      title: 'Standard Terms & Business Agreements',
      subtitle: 'Last Updated: June 11, 2026',
      badgeText: 'LEGAL DISCLAIMER',
      badgeColor: AppTheme.accentYellow,
      sections: filteredSections,
    );
  }

  Widget _buildPolicyList({
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required List<_PolicySection> sections,
  }) {
    if (sections.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off_outlined, size: 64, color: AppTheme.textLight),
              SizedBox(height: 16),
              Text(
                'No matching clauses found',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.navyBlue),
              ),
              SizedBox(height: 8),
              Text(
                'Try searching for another keyword or clear the query.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textLight),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      children: [
        // Compliance Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.navyBlue, AppTheme.navyBlue.withOpacity(0.85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.navyBlue.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Policy Items
        ...sections.map((sec) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.01),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sec.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.navyBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    sec.content,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            )),
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
        const SizedBox(height: 24),
      ],
    );
  }
}

class _PolicySection {
  final String title;
  final String content;

  _PolicySection({
    required this.title,
    required this.content,
  });
}

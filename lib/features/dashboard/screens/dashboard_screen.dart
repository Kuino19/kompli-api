import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animate_do/animate_do.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/document_service.dart';
import '../../../services/compliance_service.dart';
import '../../../core/widgets/responsive_layout.dart';
import '../../../core/widgets/web_sidebar.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<Map<String, String>> _savedDocs = [];
  int _completedTasks = 0;
  String _companyName = '';
  String? _logoPath;
  bool _logoExists = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _upcomingTasks = [];
  Map<String, bool> _taskStates = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _getDaysUntil(int month, int day) {
    final now = DateTime.now();
    var target = DateTime(now.year, month, day);
    if (target.isBefore(now)) {
      target = DateTime(now.year + 1, month, day);
    }
    final diff = target.difference(now).inDays;
    if (diff == 0) return 'Due today!';
    if (diff == 1) return 'Due tomorrow';
    return 'Due in $diff days';
  }

  String _getVatDaysUntil() {
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, 21);
    if (now.day > 21) {
      target = DateTime(now.year, now.month + 1, 21);
    }
    final diff = target.difference(now).inDays;
    if (diff == 0) return 'Due today!';
    return 'Due in $diff days';
  }

  String _getPensionDaysUntil() {
    final now = DateTime.now();
    final lastDay = DateTime(now.year, now.month + 1, 0);
    final diff = lastDay.difference(now).inDays;
    if (diff == 0) return 'Due today!';
    return 'Due in $diff days';
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final docs = await DocumentService().getDocuments();
    final complianceStatuses = await ComplianceService().loadStatus();

    final taskDefinitions = [
      {
        'id': 'cac_annual',
        'title': 'CAC Annual Returns',
        'sub': _getDaysUntil(6, 30),
        'days': 'Due: June 30',
        'icon': Icons.account_balance_outlined,
      },
      {
        'id': 'firs_cit',
        'title': 'FIRS CIT Tax Filing',
        'sub': '6 months post-year end',
        'days': 'Due: Post financial year',
        'icon': Icons.receipt_long_outlined,
        'isCritical': true,
      },
      {
        'id': 'firs_vat',
        'title': 'FIRS VAT Returns',
        'sub': 'Due 21st monthly',
        'days': _getVatDaysUntil(),
        'icon': Icons.percent_outlined,
      },
      {
        'id': 'pencom',
        'title': 'PENCOM Pension Contribution',
        'sub': 'Monthly payroll 18%',
        'days': _getPensionDaysUntil(),
        'icon': Icons.people_outline,
      },
      {
        'id': 'nsitf',
        'title': 'NSITF Employee Compensation',
        'sub': 'Monthly contribution 1%',
        'days': 'Due monthly',
        'icon': Icons.health_and_safety_outlined,
      },
      {
        'id': 'itf',
        'title': 'ITF Training Contribution',
        'sub': _getDaysUntil(4, 1),
        'days': 'Due: April 1',
        'icon': Icons.school_outlined,
      },
    ];

    Map<String, bool> states = {};
    List<Map<String, dynamic>> pending = [];
    int completed = 0;
    for (var def in taskDefinitions) {
      final taskId = def['id'] as String;
      bool isDone = complianceStatuses[taskId] ?? false;
      states[taskId] = isDone;
      if (isDone) {
        completed++;
      } else {
        pending.add(def);
      }
    }

    final logoPath = prefs.getString('logoPath');
    bool logoExists = false;
    if (logoPath != null && logoPath.isNotEmpty) {
      logoExists = await File(logoPath).exists();
    }

    if (!mounted) return;

    setState(() {
      _savedDocs = docs;
      _completedTasks = completed;
      _companyName = prefs.getString('companyName') ?? '';
      _logoPath = logoPath;
      _logoExists = logoExists;
      _upcomingTasks = pending;
      _taskStates = states;
      _isLoading = false;
    });
  }

  String _getCurrentDateString() {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final now = DateTime.now();
    // Return custom formatting like "May 2024" or current month
    return '${months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobileBody: _buildMobileScaffold(context),
      desktopBody: _buildDesktopScaffold(context),
    );
  }

  Widget _buildDesktopScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D1A),
      body: Row(
        children: [
          const WebSidebar(currentRoute: '/'),
          Expanded(
            child: _buildMainContent(context),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D1A),
      body: _buildMainContent(context),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildMainContent(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00E676)),
      );
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: CustomScrollView(
        slivers: [
          _buildSliverHeader(context),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Quick Profile Setup Banner (shown when profile is not yet personalized)
                if (_companyName.isEmpty) ...[
                  FadeInUp(
                    duration: const Duration(milliseconds: 300),
                    child: _buildQuickSetupBanner(context),
                  ),
                ],

                // Compliance Score Card
                FadeInUp(
                  duration: const Duration(milliseconds: 400),
                  child: _buildComplianceScoreCard(context),
                ),
                const SizedBox(height: 20),
                
                // Filings Tracker cards (CAC and FIRS side-by-side)
                FadeInUp(
                  delay: const Duration(milliseconds: 50),
                  duration: const Duration(milliseconds: 400),
                  child: _buildComplianceCards(context),
                ),
                const SizedBox(height: 20),
                
                // AI Insight Banner
                FadeInUp(
                  delay: const Duration(milliseconds: 100),
                  duration: const Duration(milliseconds: 400),
                  child: _buildAiInsightBanner(context),
                ),
                const SizedBox(height: 20),
                
                // Upcoming Deadlines Section
                FadeInUp(
                  delay: const Duration(milliseconds: 150),
                  duration: const Duration(milliseconds: 400),
                  child: _buildUpcomingTasksSection(context),
                ),
                const SizedBox(height: 20),

                // Quick Tools
                FadeInUp(
                  delay: const Duration(milliseconds: 200),
                  duration: const Duration(milliseconds: 400),
                  child: _buildQuickActions(context),
                ),
                const SizedBox(height: 24),
                
                // Recent Documents (Glassmorphism styled list)
                FadeInUp(
                  delay: const Duration(milliseconds: 250),
                  duration: const Duration(milliseconds: 400),
                  child: _buildDocumentsSection(),
                ),
                const SizedBox(height: 40),
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
                const SizedBox(height: 50),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverHeader(BuildContext context) {
    return SliverToBoxAdapter(
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar: Initials Badge, Bell & Search Capsule
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Profile Avatar Initials
                   GestureDetector(
                    onTap: () async {
                      await context.push('/profile');
                      _loadData();
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: _logoExists
                            ? Image.file(
                                File(_logoPath!),
                                fit: BoxFit.cover,
                              )
                            : Container(
                                color: Colors.white,
                                alignment: Alignment.center,
                                child: Text(
                                  _companyName.isNotEmpty ? _companyName.substring(0, 2).toUpperCase() : 'AD',
                                  style: const TextStyle(
                                    color: Color(0xFF090D1A),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                  
                  // Notifications & Search Capsule
                  Row(
                    children: [
                      // Notification Bell with Badge
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.notifications_none,
                              color: Colors.white,
                              size: 26,
                            ),
                            onPressed: () {},
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 8),
                      
                      // Search capsule
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search, color: Colors.white70, size: 18),
                            SizedBox(width: 6),
                            Text(
                              'Search',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Compliance Overview Title
              const Text(
                'Compliance Overview',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Welcome back, ${_companyName.isNotEmpty ? _companyName : 'Akin Davies'}. (${_getCurrentDateString()})',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComplianceScoreCard(BuildContext context) {
    final bool isUnset = _completedTasks == 0;
    final int percent = (_completedTasks == 6) ? 100 : ((_completedTasks / 6.0) * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          // Circular progress ring
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: isUnset ? 0.08 : _completedTasks / 6.0,
                  strokeWidth: 8,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isUnset ? const Color(0xFFFFB300) : const Color(0xFF00E676),
                  ),
                ),
              ),
              Text(
                isUnset ? 'START' : '$percent%',
                style: TextStyle(
                  fontSize: isUnset ? 13 : 18,
                  fontWeight: FontWeight.bold,
                  color: isUnset ? const Color(0xFFFFB300) : Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          
          // Right details column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isUnset ? "Let's Calculate Your Score:" : 'Your Compliance Score:',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Shield Flag Badge
                    Container(
                      width: 18,
                      height: 20,
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                          topLeft: Radius.circular(2),
                          topRight: Radius.circular(2),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Row(
                        children: [
                          Expanded(child: Container(color: const Color(0xFF008751))),
                          Expanded(child: Container(color: Colors.white)),
                          Expanded(child: Container(color: const Color(0xFF008751))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  isUnset ? 'Setup Baseline' : '$percent%',
                  style: TextStyle(
                    fontSize: isUnset ? 22 : 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: isUnset ? 0.08 : _completedTasks / 6.0,
                    minHeight: 6,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isUnset ? const Color(0xFFFFB300) : const Color(0xFF00E676),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isUnset
                      ? 'Complete setup to compute score for your business type.'
                      : 'Based on standard CAC & FIRS statutory filings.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComplianceCards(BuildContext context) {
    final isCacDone = _taskStates['cac_annual'] ?? false;
    final isFirsDone = _taskStates['firs_cit'] ?? false;

    final cacTask = {
      'id': 'cac_annual',
      'title': 'CAC Annual Returns',
      'sub': 'Due in 2 weeks',
      'days': 'Due: June 30',
      'icon': Icons.account_balance_outlined,
    };
    
    final firsTask = {
      'id': 'firs_cit',
      'title': 'FIRS CIT Tax Filing',
      'sub': '3 days left',
      'days': 'Due: 6 months after end',
      'icon': Icons.receipt_long_outlined,
      'isCritical': true,
    };

    return Row(
      children: [
        // CAC Card
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (!isCacDone) {
                _resolveTask(cacTask);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('CAC Annual Returns have already been filed.')),
                );
              }
            },
            child: Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF005C3A), Color(0xFF007E4C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF005C3A).withOpacity(0.3),
                    blurRadius: 8,
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
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shield_outlined, color: Colors.white, size: 20),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.white24,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.edit_document, color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Text(
                    'CAC Annual Returns',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isCacDone ? Colors.white : Colors.white24,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isCacDone ? 'Filed' : 'Pending',
                      style: TextStyle(
                        color: isCacDone ? const Color(0xFF007E4C) : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Due date',
                    style: TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                  const Text(
                    '15 Dec 2024',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: isCacDone ? 1.0 : 0.0,
                            minHeight: 4,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isCacDone ? '100%' : '0%',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        // FIRS Card
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (!isFirsDone) {
                _resolveTask(firsTask);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('FIRS Tax Filing has already been completed.')),
                );
              }
            },
            child: Container(
              height: 200,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF073024), Color(0xFF0A4E38)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF073024).withOpacity(0.3),
                    blurRadius: 8,
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
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Text(
                          'FIRS',
                          style: TextStyle(
                            color: Color(0xFF0A4E38),
                            fontWeight: FontWeight.bold,
                            fontSize: 7,
                          ),
                        ),
                      ),
                      Container(
                        width: 20,
                        height: 14,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24, width: 1),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Container(color: const Color(0xFF008751))),
                            Expanded(child: Container(color: Colors.white)),
                            Expanded(child: Container(color: const Color(0xFF008751))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Text(
                    'FIRS Tax Filing',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isFirsDone 
                          ? Colors.white 
                          : const Color(0xFFFFB300).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isFirsDone ? 'Filed' : 'In Progress',
                      style: TextStyle(
                        color: isFirsDone ? const Color(0xFF0A4E38) : const Color(0xFFFFB300),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Due date',
                    style: TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                  const Text(
                    '30 June 2024',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: isFirsDone ? 1.0 : 0.78,
                            minHeight: 4,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isFirsDone ? '100%' : '78%',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAiInsightBanner(BuildContext context) {
    final bool isPersonalized = _companyName.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF008751),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.tips_and_updates_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      isPersonalized ? 'AI Insight for $_companyName' : 'Sample AI Tax Insight',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () {
                        if (!isPersonalized) {
                          _showQuickProfileSetupSheet(context);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: isPersonalized
                              ? const Color(0xFF00E676).withValues(alpha: 0.2)
                              : const Color(0xFFFFB300).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          isPersonalized ? 'TAILORED' : 'TAP TO PERSONALIZE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isPersonalized ? const Color(0xFF00E676) : const Color(0xFFFFB300),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: () {
                    if (!isPersonalized) {
                      _showQuickProfileSetupSheet(context);
                    }
                  },
                  child: Text(
                    isPersonalized
                        ? 'Personalized Recommendation: You can save up to ₦200k by optimizing your corporate tax structure before fiscal quarter end.'
                        : 'Sample Estimate: Nigerian SMEs save up to ₦200k by optimizing tax structures. Tap here to personalize your insight.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () => _showOptimizationPlanSheet(context),
                  child: const Text(
                    'View Optimization Plan →',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00E676)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickSetupBanner(BuildContext context) {
    if (_companyName.isNotEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF008751), Color(0xFF004D2E)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.stars, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Unlock Tailored AI Insights',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Add your company name to turn sample tips into personalized legal advice.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF008751),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _showQuickProfileSetupSheet(context),
            child: const Text(
              'Set Up (1 min)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showQuickProfileSetupSheet(BuildContext context) {
    final nameCtrl = TextEditingController(text: _companyName);
    final rcCtrl = TextEditingController();
    String selectedType = 'Private Limited (Ltd)';
    final types = [
      'Private Limited (Ltd)',
      'Business Name / Sole Prop',
      'Incorporated Trustee / NGO',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (stCtx, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.fromLTRB(
                24,
                20,
                24,
                MediaQuery.of(ctx).viewInsets.bottom + 28,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Row(
                    children: [
                      Icon(Icons.stars, color: Color(0xFF00E676)),
                      SizedBox(width: 8),
                      Text(
                        'Personalize Your AI Compliance',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter your business details to unlock tailored AI insights and personalized tax optimization advice.',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: nameCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Company / Business Name',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.business, color: Color(0xFF00E676)),
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedType,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: 'Business Structure',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.gavel, color: Color(0xFF00E676)),
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    items: types.map((t) {
                      return DropdownMenuItem<String>(
                        value: t,
                        child: Text(t, style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedType = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: rcCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'RC / BN Number (Optional)',
                      labelStyle: const TextStyle(color: Colors.white70),
                      prefixIcon: const Icon(Icons.numbers, color: Color(0xFF00E676)),
                      fillColor: Colors.white.withValues(alpha: 0.06),
                      filled: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00E676),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        if (name.isNotEmpty) {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setString('companyName', name);
                          await prefs.setString('businessType', selectedType);
                          if (rcCtrl.text.trim().isNotEmpty) {
                            await prefs.setString('rcNumber', rcCtrl.text.trim());
                          }
                          if (ctx.mounted) Navigator.pop(ctx);
                          _loadData();
                        }
                      },
                      child: const Text(
                        'Personalize Now →',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showOptimizationPlanSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Row(
                children: [
                  Icon(Icons.auto_awesome, color: Color(0xFF00E676)),
                  SizedBox(width: 8),
                  Text(
                    'Tax Optimization Plan',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'AI-generated legal recommendations for your company.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
              ),
              const SizedBox(height: 20),
              _buildPlanStep(
                step: '1',
                title: 'Restructure subsidiary holdings',
                desc: 'Optimize equity distributions to declare dividends under tax-exempt thresholds.',
              ),
              const SizedBox(height: 12),
              _buildPlanStep(
                step: '2',
                title: 'Apply Pioneer Status Incentive (PSI)',
                desc: 'Check eligibility for a 3-to-5 year corporate tax holiday under current NIPC guidelines.',
              ),
              const SizedBox(height: 12),
              _buildPlanStep(
                step: '3',
                title: 'Maximize VAT deduction claims',
                desc: 'Ensure all input VAT from vendor transactions is captured and offset before FIRS monthly filings.',
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        context.push('/chat');
                      },
                      icon: const Icon(Icons.forum, size: 18),
                      label: const Text('Discuss with AI'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF008751),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlanStep({required String step, required String title, required String desc}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Colors.white10,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            step,
            style: const TextStyle(
              color: Color(0xFF00E676),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                desc,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.6),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingTasksSection(BuildContext context) {
    // Filter pending tasks (exclude cac_annual and firs_cit which are prominent in filings cards)
    final pendingTasks = _upcomingTasks.where((t) => t['id'] != 'cac_annual' && t['id'] != 'firs_cit').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Upcoming Deadlines',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            TextButton(
              onPressed: () async {
                await context.push('/compliance');
                _loadData();
              },
              child: const Text('View All', style: TextStyle(color: Color(0xFF00E676), fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (pendingTasks.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Column(
              children: [
                Icon(Icons.check_circle_outline, size: 44, color: Color(0xFF00E676)),
                SizedBox(height: 10),
                Text(
                  'No pending deadlines!',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ],
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: pendingTasks.map((task) {
                return GestureDetector(
                  onTap: () => _resolveTask(task),
                  child: Container(
                    width: 180,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task['title'].toString().contains('Pension') ? 'Pension' : 
                                task['title'].toString().contains('VAT') ? 'VAT' : 
                                task['title'].toString().replaceAll('Registration', '').replaceAll('Contribution', '').trim(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                task['days'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE8F5E9),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            task['title'].toString().contains('VAT') ? Icons.trending_up : Icons.description,
                            color: const Color(0xFF2E7D32),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Tools',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                context,
                title: 'New Document',
                icon: Icons.note_add_outlined,
                onTap: () => context.push('/generate_nda'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                context,
                title: 'Ask AI',
                icon: Icons.smart_toy_outlined,
                onTap: () => context.push('/chat'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                context,
                title: 'Upload ID',
                icon: Icons.upload_file_outlined,
                onTap: () => _startIdScanner(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(BuildContext context,
      {required String title, required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF00E676).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF00E676), size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startIdScanner(BuildContext context) async {
    final picker = ImagePicker();
    try {
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return const _ScannerAnimationDialog();
        },
      );

      await Future.delayed(const Duration(milliseconds: 2500));

      if (!mounted) return;
      Navigator.pop(context);

      _showScannerResultSheet(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ID Scan Failed: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showScannerResultSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF00E676),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.check, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Document Parsed Successfully',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'AI has successfully extracted the following business registry information:',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
              ),
              const SizedBox(height: 20),
              
              _buildExtractedField('COMPANY NAME', 'Kompli Nigeria Ltd'),
              const Divider(height: 16, color: Colors.white10),
              _buildExtractedField('REGISTRATION NUMBER', 'RC-1928374'),
              const Divider(height: 16, color: Colors.white10),
              _buildExtractedField('TAX ID (TIN)', 'TIN-92837482'),
              const Divider(height: 16, color: Colors.white10),
              _buildExtractedField('REGISTERED ADDRESS', '32 Commercial Avenue, Yaba, Lagos'),
              
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Discard'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setString('companyName', 'Kompli Nigeria Ltd');
                        await prefs.setString('rcNumber', 'RC-1928374');
                        await prefs.setString('tin', 'TIN-92837482');
                        await prefs.setString('address', '32 Commercial Avenue, Yaba, Lagos');
                        
                        if (!mounted) return;
                        Navigator.pop(context);
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.white),
                                SizedBox(width: 10),
                                Text('Business profile updated successfully!'),
                              ],
                            ),
                            backgroundColor: Color(0xFF008751),
                          ),
                        );
                        _loadData();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF008751),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Apply to Profile'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExtractedField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.4),
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Future<void> _resolveTask(Map<String, dynamic> task) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text('Filing ${task['title']}', style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Complete your obligational filing with the appropriate authority.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
              ),
              const SizedBox(height: 12),
              Text(
                'Requirements: Submitting current year declarations and paying associated processing fees.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool(task['id'] as String, true);
                
                if (!mounted) return;
                Navigator.pop(context);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Successfully filed ${task['title']}!'),
                    backgroundColor: const Color(0xFF008751),
                  ),
                );
                
                _loadData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF008751),
                foregroundColor: Colors.white,
              ),
              child: const Text('Mark as Filed'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDocumentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Documents', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
            IconButton(
              icon: const Icon(Icons.refresh, color: Color(0xFF00E676)),
              onPressed: _loadData,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_savedDocs.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              children: [
                Icon(Icons.folder_open, size: 48, color: Colors.white.withValues(alpha: 0.3)),
                const SizedBox(height: 12),
                const Text('No documents yet', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 4),
                Text('Tap Generate Document to get started', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13)),
              ],
            ),
          )
        else
          ..._savedDocs.reversed.take(5).map((doc) {
            final title = doc['title'] ?? 'Legal Document';
            final content = doc['content'] ?? '';
            return _buildDocTile(title, content);
          }),
      ],
    );
  }

  Widget _buildDocTile(String title, String fullContent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF008751).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.picture_as_pdf, color: Color(0xFF00E676), size: 22),
        ),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        subtitle: Text('Saved locally', style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.5))),
        trailing: const Icon(Icons.chevron_right, color: Colors.white60),
        onTap: () async {
          final prefs = await SharedPreferences.getInstance();
          final vaultLockEnabled = prefs.getBool('vault_lock_enabled') ?? false;
          if (!mounted) return;
          if (vaultLockEnabled) {
            context.push('/passcode', extra: {
              'isSetupMode': false,
              'onSuccess': () {
                context.pop();
                context.push('/document_preview', extra: {
                  'title': title,
                  'content': fullContent,
                });
              }
            });
          } else {
            context.push('/document_preview', extra: {
              'title': title,
              'content': fullContent,
            });
          }
        },
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: BottomNavigationBar(
        currentIndex: 0,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF00E676),
        unselectedItemColor: const Color(0xFF94A3B8),
        backgroundColor: const Color(0xFF0D1424),
        selectedFontSize: 11,
        unselectedFontSize: 11,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        onTap: (index) {
          if (index == 0) {
            // Already on Dashboard
          } else if (index == 1) {
            context.push('/compliance').then((_) => _loadData());
          } else if (index == 2) {
            _showAllDocsSheet(context);
          } else if (index == 3) {
            context.push('/chat');
          } else if (index == 4) {
            context.push('/profile').then((_) => _loadData());
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_rounded),
            activeIcon: Icon(Icons.grid_view_rounded, color: Color(0xFF00E676)),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_rounded),
            activeIcon: Icon(Icons.bar_chart_rounded, color: Color(0xFF00E676)),
            label: 'Reports',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_rounded),
            activeIcon: Icon(Icons.history_rounded, color: Color(0xFF00E676)),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.headset_mic_rounded),
            activeIcon: Icon(Icons.headset_mic_rounded, color: Color(0xFF00E676)),
            label: 'Support',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_rounded),
            activeIcon: Icon(Icons.settings_rounded, color: Color(0xFF00E676)),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  void _showAllDocsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.fromLTRB(24, 20, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Document Vault',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Secure access to all your generated contracts and files.',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
              ),
              const SizedBox(height: 20),
              if (_savedDocs.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32.0),
                    child: Column(
                      children: [
                        Icon(Icons.folder_open, size: 48, color: Colors.white.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        const Text('No documents generated yet', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.4,
                  child: ListView.builder(
                    itemCount: _savedDocs.length,
                    itemBuilder: (context, idx) {
                      final doc = _savedDocs.reversed.toList()[idx];
                      final title = doc['title'] ?? 'Legal Document';
                      final content = doc['content'] ?? '';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white24),
                        ),
                        child: ListTile(
                          leading: const Icon(Icons.description, color: Color(0xFF00E676)),
                          title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                          subtitle: Text('Saved locally & Firestore', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5))),
                          trailing: const Icon(Icons.chevron_right, size: 18, color: Colors.white54),
                          onTap: () {
                            Navigator.pop(context);
                            context.push('/document_preview', extra: {
                              'title': title,
                              'content': content,
                            });
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ScannerAnimationDialog extends StatefulWidget {
  const _ScannerAnimationDialog();

  @override
  State<_ScannerAnimationDialog> createState() => _ScannerAnimationDialogState();
}

class _ScannerAnimationDialogState extends State<_ScannerAnimationDialog> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                const SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    color: AppTheme.accentYellow,
                    strokeWidth: 4,
                  ),
                ),
                Icon(
                  Icons.document_scanner,
                  color: AppTheme.accentYellow.withOpacity(0.8),
                  size: 36,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Scanning Corporate Document',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Running OCR & AI parsing...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(
                backgroundColor: Colors.white10,
                color: Color(0xFF00E676),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:animate_do/animate_do.dart';
import '../../../services/compliance_service.dart';

// Data model for a compliance task
class ComplianceTask {
  final String id;
  final String title;
  final String body;
  final String deadline;
  final String penalty;
  final String authority;
  final IconData icon;
  final Color color;
  bool isDone;

  ComplianceTask({
    required this.id,
    required this.title,
    required this.body,
    required this.deadline,
    required this.penalty,
    required this.authority,
    required this.icon,
    required this.color,
    this.isDone = false,
  });
}

class ComplianceScreen extends StatefulWidget {
  const ComplianceScreen({super.key});

  @override
  State<ComplianceScreen> createState() => _ComplianceScreenState();
}

class _ComplianceScreenState extends State<ComplianceScreen> {
  bool _isLoading = true;
  bool _isTimelineView = false;

  final List<ComplianceTask> _tasks = [
    ComplianceTask(
      id: 'cac_annual',
      title: 'CAC Annual Returns',
      body:
          'Every registered company must file annual returns with the Corporate Affairs Commission (CAC) once a year. This confirms your company is still active and updates your registered details.',
      deadline: 'Due: June 30 every year',
      penalty: 'Penalty: ₦3,000/month late fee + risk of delisting',
      authority: 'Corporate Affairs Commission (CAC)',
      icon: Icons.account_balance_outlined,
      color: const Color(0xFF6C63FF),
    ),
    ComplianceTask(
      id: 'firs_cit',
      title: 'FIRS Company Income Tax (CIT)',
      body:
          'Company Income Tax is filed with the Federal Inland Revenue Service (FIRS). It is due 6 months after your financial year-end and requires audited financial statements.',
      deadline: 'Due: 6 months after financial year-end',
      penalty: 'Penalty: 10% of tax due + 5% per annum interest',
      authority: 'Federal Inland Revenue Service (FIRS)',
      icon: Icons.receipt_long_outlined,
      color: const Color(0xFFE67E22),
    ),
    ComplianceTask(
      id: 'firs_vat',
      title: 'FIRS VAT Returns (Monthly)',
      body:
          'If your annual turnover exceeds ₦25 million, you must register for VAT and file monthly returns with FIRS by the 21st of each following month.',
      deadline: 'Due: 21st of every month',
      penalty: 'Penalty: ₦50,000 first month + ₦25,000/month thereafter',
      authority: 'Federal Inland Revenue Service (FIRS)',
      icon: Icons.percent_outlined,
      color: const Color(0xFFE74C3C),
    ),
    ComplianceTask(
      id: 'pencom',
      title: 'PENCOM Pension Registration',
      body:
          'Companies with 15 or more employees must register with the National Pension Commission (PenCom) and contribute 18% of each employee\'s monthly emolument (10% employer + 8% employee).',
      deadline: 'One-time registration (monthly contributions)',
      penalty: 'Penalty: 2% of total monthly payroll per month of default',
      authority: 'National Pension Commission (PenCom)',
      icon: Icons.people_outline,
      color: const Color(0xFF00E676),
    ),
    ComplianceTask(
      id: 'nsitf',
      title: 'NSITF Employee Compensation',
      body:
          'The Nigeria Social Insurance Trust Fund (NSITF) requires employers to pay 1% of total monthly payroll to provide compensation for work-related injuries and diseases.',
      deadline: 'Due: Monthly (same time as payroll)',
      penalty: 'Penalty: Criminal liability + civil suits from employees',
      authority: 'Nigeria Social Insurance Trust Fund (NSITF)',
      icon: Icons.health_and_safety_outlined,
      color: const Color(0xFF2980B9),
    ),
    ComplianceTask(
      id: 'itf',
      title: 'ITF Training Contribution',
      body:
          'Companies with 25 or more employees or a turnover above ₦50 million must pay 1% of their annual payroll to the Industrial Training Fund (ITF).',
      deadline: 'Due: April 1 every year',
      penalty: 'Penalty: 5% of contribution due + legal action',
      authority: 'Industrial Training Fund (ITF)',
      icon: Icons.school_outlined,
      color: const Color(0xFF8E44AD),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final statuses = await ComplianceService().loadStatus();
    if (!mounted) return;
    setState(() {
      for (final task in _tasks) {
        task.isDone = statuses[task.id] ?? false;
      }
      _isLoading = false;
    });
  }

  Future<void> _toggle(ComplianceTask task, bool value) async {
    setState(() => task.isDone = value);
    if (value) {
      await ComplianceService().markDone(task.id);
    } else {
      await ComplianceService().markPending(task.id);
    }
  }

  int get _completedCount => _tasks.where((t) => t.isDone).length;
  double get _progress => _completedCount / _tasks.length;

  String get _healthLabel {
    if (_progress == 1.0) return 'Fully Compliant ✅';
    if (_progress >= 0.5) return 'Partially Compliant ⚠️';
    return 'Action Required 🔴';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF090D1A),
        body: Center(
            child: CircularProgressIndicator(color: Color(0xFF00E676))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF090D1A),
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: const Color(0xFF0D1424),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: _progress == 1.0
                        ? [const Color(0xFF005C3B), const Color(0xFF00E676)]
                        : _progress >= 0.5
                            ? [const Color(0xFF7A5C00), const Color(0xFFFFB300)]
                            : [const Color(0xFF7B0000), Colors.redAccent],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + kToolbarHeight,
                    left: 24,
                    right: 24,
                    bottom: 20,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _healthLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_completedCount of ${_tasks.length} obligations completed',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _progress,
                          backgroundColor: Colors.white24,
                          valueColor:
                              const AlwaysStoppedAnimation<Color>(Colors.white),
                          minHeight: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              title: const Text('Compliance Tracker',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              centerTitle: false,
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.verified_user, color: Colors.white),
                tooltip: 'Verify CAC/TIN',
                onPressed: () => context.push('/verify'),
              ),
              const SizedBox(width: 8),
            ],
          ),

          // Live Lookup Banner
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            sliver: SliverToBoxAdapter(
              child: FadeInUp(
                duration: const Duration(milliseconds: 400),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1424),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00E676).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.verified_user,
                            color: Color(0xFF00E676), size: 24),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Live CAC & TIN Lookup',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                            const SizedBox(height: 2),
                            Text('Verify corporate registry records instantly.',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 11)),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => context.push('/verify'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF00E676),
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          minimumSize: Size.zero,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Verify',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // View Toggle
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            sliver: SliverToBoxAdapter(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.list_alt, color: Colors.white70, size: 16),
                  const SizedBox(width: 4),
                  const Text(
                    'Checklist',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.white70),
                  ),
                  const SizedBox(width: 4),
                  Switch.adaptive(
                    value: _isTimelineView,
                    activeColor: const Color(0xFF00E676),
                    onChanged: (val) {
                      setState(() {
                        _isTimelineView = val;
                      });
                    },
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Timeline',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.white70),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.timeline,
                      color: Color(0xFF00E676), size: 16),
                ],
              ),
            ),
          ),

          // Task List / Timeline View
          if (!_isTimelineView)
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final task = _tasks[index];
                    return FadeInUp(
                      delay: Duration(milliseconds: index * 80),
                      duration: const Duration(milliseconds: 400),
                      child: _buildTaskCard(task),
                    );
                  },
                  childCount: _tasks.length,
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: _buildTimelineView(),
            ),

          // Bottom info card & Attribution
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverToBoxAdapter(
              child: Column(
                children: [
                  FadeInUp(
                    delay: const Duration(milliseconds: 600),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1424),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: Color(0xFF00E676), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Tick each item once completed. Your compliance score on the dashboard updates automatically.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.7),
                                  height: 1.5),
                            ),
                          ),
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
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(ComplianceTask task) {
    return GestureDetector(
      onTap: () => _showTaskDetail(task),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1424),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: task.isDone
                ? task.color
                : Colors.white.withValues(alpha: 0.08),
            width: task.isDone ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: task.isDone
                  ? task.color.withValues(alpha: 0.12)
                  : Colors.black.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => _toggle(task, !task.isDone),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: task.isDone
                        ? task.color
                        : task.color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    task.isDone ? Icons.check_rounded : task.icon,
                    color: task.isDone ? Colors.black : task.color,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: task.isDone ? task.color : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.deadline,
                      style: TextStyle(
                        fontSize: 12,
                        color: task.isDone
                            ? task.color.withValues(alpha: 0.7)
                            : Colors.white.withValues(alpha: 0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (task.isDone)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: task.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Done',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: task.color)),
                )
              else
                const Icon(Icons.chevron_right, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }

  void _showTaskDetail(ComplianceTask task) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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

            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: task.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(task.icon, color: task.color, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    task.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            Text(task.body,
                style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.85),
                    height: 1.7)),
            const SizedBox(height: 20),

            _infoRow(Icons.calendar_today_outlined, task.deadline, task.color),
            const SizedBox(height: 10),
            _infoRow(Icons.warning_amber_rounded, task.penalty, Colors.redAccent),
            const SizedBox(height: 10),
            _infoRow(
                Icons.account_balance_outlined, task.authority, Colors.white),
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showSuccessDialog(task);
                },
                icon: Icon(Icons.alarm, size: 20, color: task.color),
                label: Text('Schedule Compliance Alert',
                    style: TextStyle(
                        color: task.color, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: task.color,
                  side: BorderSide(color: task.color, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _toggle(task, !task.isDone);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: task.isDone
                      ? Colors.white.withValues(alpha: 0.1)
                      : task.color,
                  foregroundColor: task.isDone ? Colors.white : Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  task.isDone ? 'Mark as Pending' : 'Mark as Done ✓',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  void _showSuccessDialog(ComplianceTask task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0D1424),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline,
                color: Color(0xFF00E676), size: 28),
            SizedBox(width: 12),
            Text(
              'Alert Scheduled',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A compliance reminder has been scheduled for:',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: task.color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: task.color.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: task.color,
                        fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    task.deadline,
                    style: const TextStyle(fontSize: 13, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You will receive push notifications and alerts as the deadline approaches.',
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Great, thanks!',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF00E676)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineView() {
    final List<Map<String, dynamic>> milestones = [
      {
        'title': 'FIRS VAT Return (Monthly)',
        'date': 'June 21, 2026',
        'countdown': 'In 10 days',
        'color': const Color(0xFFE74C3C),
        'icon': Icons.percent_outlined,
        'description': 'File monthly VAT returns to avoid ₦50,000 late fee.',
      },
      {
        'title': 'CAC Annual Returns Filing',
        'date': 'June 30, 2026',
        'countdown': 'In 19 days',
        'color': const Color(0xFF6C63FF),
        'icon': Icons.account_balance_outlined,
        'description':
            'Mandatory annual returns filing for all registered companies.',
      },
      {
        'title': 'FIRS Company Income Tax (CIT)',
        'date': 'June 30, 2026',
        'countdown': 'In 19 days (6 months post-FY)',
        'color': const Color(0xFFE67E22),
        'icon': Icons.receipt_long_outlined,
        'description':
            'Submit CIT audits and declarations to avoid 10% interest penalty.',
      },
      {
        'title': 'NSITF Contribution (Monthly)',
        'date': 'June 30, 2026',
        'countdown': 'In 19 days (Payroll run)',
        'color': const Color(0xFF2980B9),
        'icon': Icons.health_and_safety_outlined,
        'description': '1% employee compensation fund payment.',
      },
      {
        'title': 'PENCOM Pension Remittance',
        'date': 'July 14, 2026',
        'countdown': 'In 33 days (7 days post-month)',
        'color': const Color(0xFF00E676),
        'icon': Icons.people_outline,
        'description':
            'Monthly 18% total payroll pension contributions transfer.',
      },
      {
        'title': 'ITF Training Contribution',
        'date': 'April 1, 2027',
        'countdown': 'Next year',
        'color': const Color(0xFF8E44AD),
        'icon': Icons.school_outlined,
        'description': 'Annual 1% training fund levy contribution.',
      },
    ];

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final milestone = milestones[index];
          final isLast = index == milestones.length - 1;
          return FadeInUp(
            delay: Duration(milliseconds: index * 60),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: milestone['color'] as Color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (milestone['color'] as Color).withValues(alpha: 0.3),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(milestone['icon'] as IconData,
                          color: Colors.black, size: 10),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 90,
                        color: Colors.white24,
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1424),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                milestone['title'] as String,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: Colors.white),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: (milestone['color'] as Color)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                milestone['countdown'] as String,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: milestone['color'] as Color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Deadline: ${milestone['date']}',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.5)),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          milestone['description'] as String,
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.7),
                              height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        childCount: milestones.length,
      ),
    );
  }
}

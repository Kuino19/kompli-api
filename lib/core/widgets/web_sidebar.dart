import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';

class WebSidebar extends StatelessWidget {
  final String currentRoute;
  
  const WebSidebar({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          right: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo Area
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 24),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: AppTheme.primaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Kompli',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.navyBlue,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Navigation Links
          _buildNavItem(context, 'Dashboard', Icons.dashboard_outlined, '/', currentRoute == '/'),
          _buildNavItem(context, 'AI Assistant', Icons.auto_awesome, '/chat', currentRoute == '/chat'),
          _buildNavItem(context, 'Compliance', Icons.calendar_today_outlined, '/compliance', currentRoute == '/compliance'),
          _buildNavItem(context, 'Profile', Icons.person_outline, '/profile', currentRoute == '/profile'),
          
          const Spacer(),
          
          // Bottom Settings / Logout
          _buildNavItem(context, 'Logout', Icons.logout, '/login', false),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, String title, IconData icon, String route, bool isSelected) {
    return InkWell(
      onTap: () {
        if (route == '/login') {
          // Handle logout logic if needed, then pop to login
          context.go('/login');
        } else if (!isSelected) {
          context.push(route);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryGreen.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade600,
              size: 22,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade700,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

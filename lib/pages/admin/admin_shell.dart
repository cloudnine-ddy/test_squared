import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/theme_provider.dart';
import '../../core/services/toast_service.dart';
import 'upload_paper_view.dart';
import 'question_manager_view.dart';
import 'analytics_dashboard_view.dart';

/// Enum for admin navigation items - add new items here for future features
enum AdminSection {
  dashboard,
  uploadPaper,
  questionManager,
  // Add future sections here:
  // userManagement,
  // settings,
}

/// Main admin shell with sidebar navigation
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  bool _isCheckingAccess = true;
  AdminSection _currentSection = AdminSection.dashboard;
  bool _isSidebarExpanded = true;

  @override
  void initState() {
    super.initState();
    _checkAdminAccess();
  }

  Future<void> _checkAdminAccess() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      _redirectNonAdmin();
      return;
    }

    try {
      final profile = await supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      final role = (profile?['role'] as String?)?.toLowerCase();

      if (role != 'admin') {
        _redirectNonAdmin();
        return;
      }

      if (mounted) {
        setState(() {
          _isCheckingAccess = false;
        });
      }
    } catch (_) {
      _redirectNonAdmin();
    }
  }

  void _redirectNonAdmin() {
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ToastService.showError('Access Denied');
      context.go('/dashboard');
    });
  }

  Future<void> _handleLogout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      ToastService.showError('Failed to log out');
    }
  }

  Widget _buildCurrentView() {
    switch (_currentSection) {
      case AdminSection.dashboard:
        return const AnalyticsDashboardView();
      case AdminSection.uploadPaper:
        return const UploadPaperView();
      case AdminSection.questionManager:
        return const QuestionManagerView();
      // Add future cases here:
    }
  }

  String _getSectionTitle(AdminSection section) {
    switch (section) {
      case AdminSection.dashboard:
        return 'Dashboard';
      case AdminSection.uploadPaper:
        return 'Upload Papers';
      case AdminSection.questionManager:
        return 'Question Manager';
      // Add future cases here
    }
  }

  IconData _getSectionIcon(AdminSection section) {
    switch (section) {
      case AdminSection.dashboard:
        return Icons.dashboard_rounded;
      case AdminSection.uploadPaper:
        return Icons.upload_file;
      case AdminSection.questionManager:
        return Icons.account_tree;
      // Add future cases here
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAccess) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isSidebarExpanded ? 240 : 72,
            child: _buildSidebar(),
          ),
          // Divider
          Container(
            width: 1,
            color: AppColors.sidebar.withValues(alpha: 0.5),
          ),
          // Main content
          Expanded(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(child: _buildCurrentView()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      color: AppColors.sidebar, // Deep dark blue
      child: Column(
        children: [
          // Header
          Container(
            height: 64,
            padding: EdgeInsets.symmetric(
              horizontal: _isSidebarExpanded ? 20 : 0,
            ),
            child: Row(
              children: [
                if (_isSidebarExpanded) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Admin Portal',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ] else
                  Center(
                    child: Container(
                      width: 72,
                      padding: const EdgeInsets.all(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _buildNavItem(AdminSection.dashboard),
                _buildNavItem(AdminSection.uploadPaper),
                _buildNavItem(AdminSection.questionManager),
                // Add more navigation items here as needed
                // _buildNavItem(AdminSection.analytics),
              ],
            ),
          ),
          // Bottom section with theme toggle and logout
          Container(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Divider(color: Colors.white.withValues(alpha: 0.1)),
                const SizedBox(height: 8),
                // Theme toggle button
                /*
                // Theme toggle disabled during refactor
                Consumer<ThemeProvider>(
                  builder: (context, themeProvider, _) => _buildFooterButton(
                    icon: themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                    label: themeProvider.isDarkMode ? 'Light Mode' : 'Dark Mode',
                    onTap: () => themeProvider.toggleTheme(),
                  ),
                ),
                */
                const SizedBox(height: 4),
                _buildLogoutButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(AdminSection section) {
    final isSelected = _currentSection == section;
    final icon = _getSectionIcon(section);
    final title = _getSectionTitle(section);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _currentSection = section;
            });
          },
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: _isSidebarExpanded ? 16 : 0,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF6366F1).withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    )
                  : null,
            ),
            child: Row(
              mainAxisAlignment: _isSidebarExpanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? const Color(0xFF818CF8)
                      : Colors.white.withValues(alpha: 0.6),
                  size: 22,
                ),
                if (_isSidebarExpanded) ...[
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.7),
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _handleLogout,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: _isSidebarExpanded ? 16 : 0,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: _isSidebarExpanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Icon(
                Icons.logout_rounded,
                color: Colors.red.withValues(alpha: 0.8),
                size: 22,
              ),
              if (_isSidebarExpanded) ...[
                const SizedBox(width: 12),
                Text(
                  'Logout',
                  style: TextStyle(
                    color: Colors.red.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: _isSidebarExpanded ? 16 : 0,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: _isSidebarExpanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: Colors.white.withValues(alpha: 0.7),
                size: 22,
              ),
              if (_isSidebarExpanded) ...[
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppColors.sidebar,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          // Toggle sidebar button
          IconButton(
            onPressed: () {
              setState(() {
                _isSidebarExpanded = !_isSidebarExpanded;
              });
            },
            icon: Icon(
              _isSidebarExpanded ? Icons.menu_open : Icons.menu,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            tooltip: _isSidebarExpanded ? 'Collapse sidebar' : 'Expand sidebar',
          ),
          const SizedBox(width: 16),
          // Current section title
          Text(
            _getSectionTitle(_currentSection),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // User info badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF6366F1).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.verified_user,
                  color: Color(0xFF818CF8),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'Admin',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

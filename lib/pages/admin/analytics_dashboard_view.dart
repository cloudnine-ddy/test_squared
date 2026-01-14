import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_colors.dart';
import '../../core/services/toast_service.dart';
import '../../features/admin/data/analytics_repository.dart';

class AnalyticsDashboardView extends StatefulWidget {
  const AnalyticsDashboardView({super.key});

  @override
  State<AnalyticsDashboardView> createState() => _AnalyticsDashboardViewState();
}

class _AnalyticsDashboardViewState extends State<AnalyticsDashboardView> {
  final _analyticsRepo = AnalyticsRepository();
  
  bool _isLoading = true;
  Map<String, dynamic> _overallStats = {};
  List<Map<String, dynamic>> _topicPopularity = [];
  Map<String, dynamic> _contentMetrics = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        _analyticsRepo.getOverallAnalytics(),
        _analyticsRepo.getTopicPopularity(limit: 10),
        _analyticsRepo.getContentMetrics(),
      ]);

      if (mounted) {
        setState(() {
          _overallStats = results[0] as Map<String, dynamic>;
          _topicPopularity = results[1] as List<Map<String, dynamic>>;
          _contentMetrics = results[2] as Map<String, dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastService.showError('Failed to load analytics');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF37352F)))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Admin Dashboard',
                      style: TextStyle(
                        color: Color(0xFF37352F),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Usage Stats
                    _buildUsageStats(),
                    const SizedBox(height: 24),
                    
                    // Content Metrics
                    _buildContentMetrics(),
                    const SizedBox(height: 24),
                    
                    // Topic Popularity
                    _buildTopicPopularity(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildUsageStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Usage Statistics',
          style: TextStyle(
            color: Color(0xFF37352F),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Users',
                _overallStats['total_users']?.toString() ?? '0',
                Icons.people_outline,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                'Active (7d)',
                _overallStats['active_users_7d']?.toString() ?? '0',
                Icons.trending_up,
                Colors.green,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                'Active (30d)',
                _overallStats['active_users_30d']?.toString() ?? '0',
                Icons.calendar_today_outlined,
                Colors.purple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Attempts',
                _overallStats['total_attempts']?.toString() ?? '0',
                Icons.quiz_outlined,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                'Avg Score',
                '${(_overallStats['avg_platform_score'] ?? 0).toStringAsFixed(1)}%',
                Icons.star_outline,
                Colors.amber,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                'Bookmarks',
                _overallStats['total_bookmarks']?.toString() ?? '0',
                Icons.bookmark_outline,
                Colors.red,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFE9E9E7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF787774), size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF787774),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF37352F),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentMetrics() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFE9E9E7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Content Metrics',
            style: TextStyle(
              color: Color(0xFF37352F),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildMetricRow('Subjects', _contentMetrics['total_subjects']?.toString() ?? '0'),
          const Divider(height: 1, color: Color(0xFFE9E9E7)),
          _buildMetricRow('Papers', _contentMetrics['total_papers']?.toString() ?? '0'),
          const Divider(height: 1, color: Color(0xFFE9E9E7)),
          _buildMetricRow('Questions', _contentMetrics['total_questions']?.toString() ?? '0'),
          const Divider(height: 1, color: Color(0xFFE9E9E7)),
          _buildMetricRow('With Figures', _contentMetrics['questions_with_figures']?.toString() ?? '0'),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF787774),
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF37352F),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicPopularity() {
    if (_topicPopularity.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFE9E9E7),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Topic Popularity',
            style: TextStyle(
              color: Color(0xFF37352F),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ..._topicPopularity.take(10).map((topic) {
            final name = topic['topic_name'] as String;
            final attempts = topic['attempt_count'] as int;
            final users = topic['unique_users'] as int;
            
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            color: Color(0xFF37352F),
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        '$attempts attempts',
                        style: const TextStyle(
                          color: Color(0xFF787774),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: attempts / (_topicPopularity.first['attempt_count'] as int),
                      minHeight: 4,
                      backgroundColor: const Color(0xFFF7F6F3),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF37352F)),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

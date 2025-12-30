import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/toast_service.dart';
import '../data/progress_repository.dart';
import '../models/topic_stats_model.dart';
import '../../past_papers/data/past_paper_repository.dart';
import '../../past_papers/models/topic_model.dart';
import '../widgets/stat_card.dart';
import '../widgets/mastery_badge.dart';
import '../widgets/streak_indicator.dart';
import '../widgets/daily_progress_chart.dart';

class ProgressDashboardScreen extends StatefulWidget {
  const ProgressDashboardScreen({super.key});

  @override
  State<ProgressDashboardScreen> createState() => _ProgressDashboardScreenState();
}

class _ProgressDashboardScreenState extends State<ProgressDashboardScreen> {
  final _progressRepo = ProgressRepository();
  final _paperRepo = PastPaperRepository();
  
  bool _isLoading = true;
  Map<String, dynamic> _overallStats = {};
  List<TopicStatsModel> _topicStats = [];
  List<Map<String, dynamic>> _weakAreas = [];
  Map<String, TopicModel> _topicsMap = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Load all data in parallel
      final results = await Future.wait([
        _progressRepo.getUserOverallStats(userId),
        _progressRepo.getUserTopicStats(userId),
        _progressRepo.getWeakAreas(userId),
        _loadAllTopics(),
      ]);

      // Create topics map for quick lookup
      final topics = results[3] as List<TopicModel>;
      _topicsMap = {for (var topic in topics) topic.id: topic};

      if (mounted) {
        setState(() {
          _overallStats = results[0] as Map<String, dynamic>;
          _topicStats = results[1] as List<TopicStatsModel>;
          _weakAreas = results[2] as List<Map<String, dynamic>>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastService.showError('Failed to load progress data');
      }
    }
  }

  Future<List<TopicModel>> _loadAllTopics() async {
    // Fetch all topics from database
    final data = await Supabase.instance.client
        .from('topics')
        .select();
    
    return (data as List).map((json) => TopicModel.fromMap(json)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDeepest,
      appBar: AppBar(
        title: const Text('My Progress'),
        backgroundColor: AppTheme.surfaceDark,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Daily Progress Chart
                    FutureBuilder<List<Map<String, dynamic>>>(
                      future: _progressRepo.getDailyQuestionStats(
                        userId: Supabase.instance.client.auth.currentUser!.id,
                        days: 7,
                      ),
                      builder: (context, snapshot) {
                        final dailyStats = snapshot.data ?? [];
                        return DailyProgressChart(
                          dailyStats: dailyStats,
                          daysToShow: 7,
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Overall Stats Cards
                    _buildOverallStats(),
                    const SizedBox(height: 24),

                    // Streak Indicator
                    StreakIndicator(
                      currentStreak: _overallStats['current_streak'] ?? 0,
                      longestStreak: _overallStats['longest_streak'] ?? 0,
                    ),
                    const SizedBox(height: 24),

                    // Weak Areas Section
                    if (_weakAreas.isNotEmpty) ...[
                      _buildSectionHeader('Areas to Improve'),
                      const SizedBox(height: 12),
                      _buildWeakAreas(),
                      const SizedBox(height: 24),
                    ],

                    // Topic Mastery Grid
                    _buildSectionHeader('Topic Mastery'),
                    const SizedBox(height: 12),
                    _buildTopicMasteryGrid(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOverallStats() {
    final totalAttempts = _overallStats['total_attempts'] ?? 0;
    final totalQuestions = _overallStats['total_questions_attempted'] ?? 0;
    final accuracy = _overallStats['overall_accuracy'] ?? 0.0;
    final avgScore = _overallStats['avg_score'] ?? 0.0;

    return Row(
      children: [
        Expanded(
          child: StatCard(
            icon: Icons.quiz_outlined,
            iconColor: Colors.blue,
            title: 'Questions',
            value: totalQuestions.toString(),
            subtitle: '$totalAttempts attempts',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            icon: Icons.check_circle_outline,
            iconColor: Colors.green,
            title: 'Accuracy',
            value: '${accuracy.toStringAsFixed(1)}%',
            subtitle: 'Overall',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: StatCard(
            icon: Icons.star_outline,
            iconColor: Colors.amber,
            title: 'Avg Score',
            value: '${avgScore.toStringAsFixed(0)}%',
            subtitle: 'Per question',
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildWeakAreas() {
    return Column(
      children: _weakAreas.map((area) {
        final topicName = area['topic_name'] as String;
        final accuracy = (area['accuracy'] as num?)?.toDouble() ?? 0.0;
        final attempts = area['total_attempts'] ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.orange.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.trending_down,
                color: Colors.orange,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topicName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '$attempts attempts • ${accuracy.toStringAsFixed(1)}% accuracy',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  // TODO: Navigate to practice mode for this topic
                  ToastService.showInfo('Practice mode coming soon!');
                },
                child: const Text('Practice'),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTopicMasteryGrid() {
    if (_topicStats.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppTheme.surfaceDark,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.school_outlined,
                size: 48,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 12),
              Text(
                'Start practicing to see your progress!',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: _topicStats.length,
      itemBuilder: (context, index) {
        final stats = _topicStats[index];
        final topic = _topicsMap[stats.topicId];

        return _buildTopicMasteryCard(stats, topic);
      },
    );
  }

  Widget _buildTopicMasteryCard(TopicStatsModel stats, TopicModel? topic) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  topic?.name ?? 'Unknown Topic',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              MasteryBadge(level: stats.masteryLevel),
            ],
          ),
          const Spacer(),
          Text(
            '${stats.accuracyDisplay} accuracy',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${stats.totalAttempts} attempts',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

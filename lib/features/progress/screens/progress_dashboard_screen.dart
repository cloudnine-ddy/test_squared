import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/services/toast_service.dart';
import '../data/progress_repository.dart';
import '../models/topic_stats_model.dart';
import '../../past_papers/data/past_paper_repository.dart';
import '../../past_papers/models/topic_model.dart';
import '../../past_papers/models/subject_model.dart';
import '../widgets/stat_card.dart';
import '../widgets/mastery_badge.dart';
import '../widgets/streak_indicator.dart';
import '../widgets/daily_progress_chart.dart';
import '../../../shared/wired/wired_widgets.dart';

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
  Map<String, SubjectModel> _subjectsMap = {};
  List<Map<String, dynamic>> _dailyStats = [];

  int _calculatedCurrentStreak = 0;
  int _calculatedLongestStreak = 0;

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
        _paperRepo.getSubjects(), // Fetch all subjects
        _progressRepo.getDailyQuestionStats(userId: userId, days: 365), // Fetch year data for streak calc
      ]);

      // Create maps for quick lookup
      final topics = results[3] as List<TopicModel>;
      _topicsMap = {for (var topic in topics) topic.id: topic};

      final subjects = results[4] as List<SubjectModel>;
      _subjectsMap = {for (var subject in subjects) subject.id: subject};

      final dailyStats = results[5] as List<Map<String, dynamic>>;
      _calculateStreaks(dailyStats);

      if (mounted) {
        setState(() {
          _overallStats = results[0] as Map<String, dynamic>;
          _topicStats = results[1] as List<TopicStatsModel>;
          _weakAreas = results[2] as List<Map<String, dynamic>>;
          _dailyStats = dailyStats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // ToastService.showError('Failed to load progress data');
        print('Error loading progress data: $e');
      }
    }
  }

  void _calculateStreaks(List<Map<String, dynamic>> stats) {
    if (stats.isEmpty) {
      _calculatedCurrentStreak = 0;
      _calculatedLongestStreak = 0;
      return;
    }

    // Sort by date ascending
    stats.sort((a, b) => DateTime.parse(a['date']).compareTo(DateTime.parse(b['date'])));

    // Create a set of dates where user was active
    final activeDates = <String>{};
    for (var stat in stats) {
      if ((stat['questions_solved'] as int) > 0) {
        activeDates.add(stat['date'].toString().split('T')[0]); // YYYY-MM-DD
      }
    }

    if (activeDates.isEmpty) {
      _calculatedCurrentStreak = 0;
      _calculatedLongestStreak = 0;
      return;
    }

    final today = DateTime.now();
    final todayStr = today.toIso8601String().split('T')[0];
    final yesterdayStr = today.subtract(const Duration(days: 1)).toIso8601String().split('T')[0];

    // Calculate Current Streak
    int current = 0;
    // If active today, start checking from today. If not active today but active yesterday, start from yesterday.
    DateTime checkDate = activeDates.contains(todayStr) ? today : today.subtract(const Duration(days: 1));

    // Edge case: if not active today AND not active yesterday, streak is 0
    if (!activeDates.contains(todayStr) && !activeDates.contains(yesterdayStr)) {
      current = 0;
    } else {
      while (true) {
        final dateStr = checkDate.toIso8601String().split('T')[0];
        if (activeDates.contains(dateStr)) {
          current++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
    }

    // Calculate Longest Streak
    int longest = 0;
    int temp = 0;

    // Need to iterate through all days in range to check for gaps
    // Just iterating activeDates isn't enough because we need to know consecutive days
    // But since activeDates are sorted if we parse them... better approach:
    // Convert activeDates to List<DateTime> sorted
    final sortedDates = activeDates.map((e) => DateTime.parse(e)).toList()
      ..sort((a, b) => a.compareTo(b));

    if (sortedDates.isNotEmpty) {
      temp = 1;
      longest = 1;
      for (int i = 0; i < sortedDates.length - 1; i++) {
        final d1 = sortedDates[i];
        final d2 = sortedDates[i+1];
        final diff = d2.difference(d1).inDays;

        if (diff == 1) {
          temp++;
        } else {
          temp = 1;
        }
        if (temp > longest) longest = temp;
      }
    }

    _calculatedCurrentStreak = current;
    _calculatedLongestStreak = longest;
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
    // Sketchy Theme Colors
    const Color primaryColor = Color(0xFF2D3E50); // Deep Navy
    const Color backgroundColor = Color(0xFFFDFBF7); // Cream beige

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          'My Progress',
          style: TextStyle(
            fontFamily: 'PatrickHand',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: primaryColor,
          ),
        ),
        centerTitle: true,
        backgroundColor: backgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryColor),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : RefreshIndicator(
              onRefresh: _loadData,
              color: primaryColor,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Daily Progress Chart
                    DailyProgressChart(
                      dailyStats: _dailyStats,
                      daysToShow: 7,
                    ),
                    const SizedBox(height: 24),

                    // Overall Stats Cards
                    _buildOverallStats(),
                    const SizedBox(height: 24),

                    // Streak Indicator
                    StreakIndicator(
                      currentStreak: _calculatedCurrentStreak,
                      longestStreak: _calculatedLongestStreak,
                    ),
                    const SizedBox(height: 32),

                    // Weak Areas Section
                    if (_weakAreas.isNotEmpty) ...[
                      _buildSectionHeader('Areas to Improve'),
                      const SizedBox(height: 16),
                      _buildWeakAreas(),
                      const SizedBox(height: 32),
                    ],

                    // Topic Mastery Grid
                    _buildSectionHeader('Topic Mastery'),
                    const SizedBox(height: 16),
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
        const SizedBox(width: 16),
        Expanded(
          child: StatCard(
            icon: Icons.check_circle_outline,
            iconColor: Colors.green,
            title: 'Accuracy',
            value: '${accuracy.toStringAsFixed(1)}%',
            subtitle: 'Overall',
          ),
        ),
        const SizedBox(width: 16),
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
        fontFamily: 'PatrickHand',
        color: Color(0xFF2D3E50),
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildWeakAreas() {
    const primaryColor = Color(0xFF2D3E50);
    
    return Column(
      children: _weakAreas.map((area) {
        final topicName = area['topic_name'] as String;
        final accuracy = (area['accuracy'] as num?)?.toDouble() ?? 0.0;
        final attempts = area['total_attempts'] ?? 0;

        String? subjectName;
        String? topicId = area['topic_id'];

        if (topicId != null) {
          final topic = _topicsMap[topicId];
          if (topic != null) {
            subjectName = _subjectsMap[topic.subjectId]?.name;
          }
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: WiredCard(
            backgroundColor: const Color(0xFFEAE4D9).withValues(alpha: 0.3),
            borderColor: primaryColor.withValues(alpha: 0.2),
            borderWidth: 1.5,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                WiredCard(
                  padding: const EdgeInsets.all(8),
                  backgroundColor: Colors.orange.withValues(alpha: 0.1),
                  borderColor: Colors.orange.withValues(alpha: 0.3),
                  borderWidth: 1,
                  child: const Icon(
                    Icons.trending_down,
                    color: Colors.orange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (subjectName != null)
                        Text(
                          subjectName.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'PatrickHand',
                            color: primaryColor.withValues(alpha: 0.6),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      Text(
                        topicName,
                        style: const TextStyle(
                          fontFamily: 'PatrickHand',
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$attempts attempts • ${accuracy.toStringAsFixed(1)}% accuracy',
                        style: TextStyle(
                          fontFamily: 'PatrickHand',
                          color: primaryColor.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                WiredButton(
                  onPressed: () {
                    if (topicId != null) {
                      context.push('/topic/$topicId');
                    } else {
                      ToastService.showInfo('Topic details unavailable');
                    }
                  },
                  backgroundColor: Colors.white,
                  filled: true,
                  borderColor: primaryColor.withValues(alpha: 0.3),
                  child: const Text(
                    'Practice',
                    style: TextStyle(
                      fontFamily: 'PatrickHand',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTopicMasteryGrid() {
    const primaryColor = Color(0xFF2D3E50);

    if (_topicStats.isEmpty) {
      return WiredCard(
        backgroundColor: const Color(0xFFEAE4D9).withValues(alpha: 0.3),
        borderColor: primaryColor.withValues(alpha: 0.2),
        borderWidth: 1.5,
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.school_outlined,
                size: 48,
                color: primaryColor.withValues(alpha: 0.2),
              ),
              const SizedBox(height: 12),
              Text(
                'Start practicing to see your progress!',
                style: TextStyle(
                  fontFamily: 'PatrickHand',
                  fontSize: 18,
                  color: primaryColor.withValues(alpha: 0.6),
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
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 180, // Fixed height to prevent excessive whitespace
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
    const primaryColor = Color(0xFF2D3E50);

    SubjectModel? subject;
    if (topic != null) {
      subject = _subjectsMap[topic.subjectId];
    }

    return WiredCard(
      backgroundColor: Colors.white,
      borderColor: primaryColor.withValues(alpha: 0.2),
      borderWidth: 1.5,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (subject != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                subject.name.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'PatrickHand',
                  color: primaryColor.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  topic?.name ?? 'Unknown Topic',
                  style: const TextStyle(
                    fontFamily: 'PatrickHand',
                    color: primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // We'll keep MasteryBadge as is for now, assuming it blends or is small enough
              MasteryBadge(level: stats.masteryLevel),
            ],
          ),
          const Spacer(),
          Text(
            '${stats.accuracyDisplay} accuracy',
            style: TextStyle(
              fontFamily: 'PatrickHand',
              color: primaryColor.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${stats.totalAttempts} attempts',
            style: TextStyle(
              fontFamily: 'PatrickHand',
              color: primaryColor.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';

/// Widget to display daily question solving progress as a bar chart
class DailyProgressChart extends StatelessWidget {
  final List<Map<String, dynamic>> dailyStats;
  final int daysToShow;

  const DailyProgressChart({
    super.key,
    required this.dailyStats,
    this.daysToShow = 7,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.sidebar,
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
              Icon(
                Icons.trending_up,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Daily Progress',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Questions solved in the last $daysToShow days',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: dailyStats.isEmpty
                ? _buildEmptyState()
                : _buildChart(),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bar_chart,
            size: 48,
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 12),
          Text(
            'No activity yet',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Start solving questions to see your progress!',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    // Prepare data for the last N days
    final now = DateTime.now();
    final chartData = <DateTime, int>{};
    
    // Initialize all days with 0
    for (int i = 0; i < daysToShow; i++) {
      final date = now.subtract(Duration(days: i));
      chartData[DateTime(date.year, date.month, date.day)] = 0;
    }
    
    // Fill in actual data
    for (final stat in dailyStats) {
      final dateStr = stat['date'] as String;
      final date = DateTime.parse(dateStr);
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final count = (stat['questions_solved'] as num).toInt();
      
      if (chartData.containsKey(normalizedDate)) {
        chartData[normalizedDate] = count;
      }
    }
    
    // Sort by date
    final sortedEntries = chartData.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    
    final maxY = sortedEntries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble();
    final adjustedMaxY = maxY == 0 ? 10.0 : maxY * 1.2;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: adjustedMaxY,
        minY: 0,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final date = sortedEntries[group.x.toInt()].key;
              final count = rod.toY.toInt();
              return BarTooltipItem(
                '${date.month}/${date.day}\n$count question${count != 1 ? 's' : ''}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= sortedEntries.length) return const SizedBox();
                final date = sortedEntries[value.toInt()].key;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 10,
                    ),
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                if (value == meta.max || value == meta.min) return const SizedBox();
                return Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: adjustedMaxY / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.white.withValues(alpha: 0.1),
              strokeWidth: 1,
            );
          },
        ),
        borderData: FlBorderData(show: false),
        barGroups: sortedEntries.asMap().entries.map((entry) {
          final index = entry.key;
          final count = entry.value.value;
          
          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: count.toDouble(),
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.7),
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 16,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

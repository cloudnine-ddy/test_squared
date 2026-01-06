import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';

/// Widget to display daily question solving progress as a smooth line chart
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFEAE4D9).withValues(alpha: 0.5), // Matches the beige paper look
        borderRadius: BorderRadius.circular(20),
        // No border or shadow as per typical clean paper look, but can add if needed
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.trending_up,
                color: Colors.black87,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Daily Progress',
                style: TextStyle(
                  color: Colors.black87,
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
              color: Colors.black.withValues(alpha: 0.6),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
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
            Icons.show_chart,
            size: 48,
            color: Colors.black.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 12),
          Text(
            'No activity yet',
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.4),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    // Prepare data
    final now = DateTime.now();
    final chartData = <DateTime, int>{};

    for (int i = 0; i < daysToShow; i++) {
        // Use days from today backwards (e.g., 6, 5, 4, 3, 2, 1, 0 days ago)
      final date = now.subtract(Duration(days: (daysToShow - 1) - i));
      chartData[DateTime(date.year, date.month, date.day)] = 0;
    }

    for (final stat in dailyStats) {
      final dateStr = stat['date'] as String;
      final date = DateTime.parse(dateStr);
      final normalizedDate = DateTime(date.year, date.month, date.day);
      final count = (stat['questions_solved'] as num).toInt();
      if (chartData.containsKey(normalizedDate)) {
        chartData[normalizedDate] = count;
      }
    }

    final sortedEntries = chartData.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final maxY = sortedEntries.map((e) => e.value).reduce((a, b) => a > b ? a : b).toDouble();
    // Ensure we have some height even if max is 0
    final adjustedMaxY = maxY == 0 ? 5.0 : maxY * 1.2;

    List<FlSpot> spots = [];
    for (int i = 0; i < sortedEntries.length; i++) {
      spots.add(FlSpot(i.toDouble(), sortedEntries[i].value.toDouble()));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: adjustedMaxY / 4,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.black.withValues(alpha: 0.05),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= sortedEntries.length) return const SizedBox();
                final date = sortedEntries[index].key;
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    '${date.day}',
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true, // Show Y axis labels? Maybe hide for cleaner look or keep subtle.
              interval: (adjustedMaxY / 4).ceilToDouble(),
              getTitlesWidget: (value, meta) {
                  if (value == 0 || value > maxY) return const SizedBox();
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.3),
                      fontSize: 10,
                    ),
                  );
              },
              reservedSize: 20,
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          handleBuiltInTouches: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => const Color(0xFF1E2B3D),
            tooltipRoundedRadius: 8,
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final index = barSpot.x.toInt();
                if (index < 0 || index >= sortedEntries.length) return null;

                final date = sortedEntries[index].key;
                final count = barSpot.y.toInt();

                const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                final dateStr = '${months[date.month - 1]} ${date.day}';

                return LineTooltipItem(
                  '$dateStr\n',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  children: [
                    TextSpan(
                      text: '$count question${count != 1 ? 's' : ''}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.normal,
                        fontSize: 12,
                      ),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (daysToShow - 1).toDouble(),
        minY: 0,
        maxY: adjustedMaxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF4A6572), // Muted dark blue/grey line
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: const Color(0xFF2196F3), // Bright blue accent for dots
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF2196F3).withValues(alpha: 0.2),
                  const Color(0xFF2196F3).withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/wired/wired_widgets.dart';

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
    const primaryColor = Color(0xFF2D3E50);

    return WiredCard(
      backgroundColor: const Color(0xFFFDFBF7), // Creamy paper
      borderColor: primaryColor.withValues(alpha: 0.5),
      borderWidth: 1.5,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.trending_up,
                color: primaryColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              const Text(
                'Daily Progress',
                style: TextStyle(
                  fontFamily: 'PatrickHand',
                  color: primaryColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Questions solved in the last $daysToShow days',
            style: TextStyle(
              fontFamily: 'PatrickHand',
              color: primaryColor.withValues(alpha: 0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: dailyStats.isEmpty
                ? _buildEmptyState()
                : _buildChart(primaryColor),
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
          CustomPaint(
            painter: WiredBorderPainter(
              color: Colors.grey.withValues(alpha: 0.3),
              strokeWidth: 1,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Icon(
                Icons.show_chart,
                size: 32,
                color: Colors.grey.withValues(alpha: 0.3),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No activity yet',
            style: TextStyle(
              fontFamily: 'PatrickHand',
              color: Colors.black.withValues(alpha: 0.4),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(Color primaryColor) {
    // Prepare data
    final now = DateTime.now();
    final chartData = <DateTime, int>{};

    for (int i = 0; i < daysToShow; i++) {
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

    final maxY = sortedEntries.map((e) => e.value).fold(0, (a, b) => a > b ? a : b).toDouble();
    final adjustedMaxY = maxY == 0 ? 5.0 : maxY * 1.2;

    List<FlSpot> spots = [];
    for (int i = 0; i < sortedEntries.length; i++) {
        spots.add(FlSpot(i.toDouble(), sortedEntries[i].value.toDouble()));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: adjustedMaxY / 4,
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: primaryColor.withValues(alpha: 0.1),
              strokeWidth: 1,
              dashArray: [5, 5],
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: primaryColor.withValues(alpha: 0.05),
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
                      fontFamily: 'PatrickHand',
                      color: primaryColor.withValues(alpha: 0.6),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: (adjustedMaxY / 4).ceilToDouble(),
              getTitlesWidget: (value, meta) {
                  if (value == 0 || value > maxY) return const SizedBox();
                  return Text(
                    value.toInt().toString(),
                    style: TextStyle(
                      fontFamily: 'PatrickHand',
                      color: primaryColor.withValues(alpha: 0.4),
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
            getTooltipColor: (_) => primaryColor,
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
                    fontFamily: 'PatrickHand',
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  children: [
                    TextSpan(
                      text: '$count question${count != 1 ? 's' : ''}',
                      style: TextStyle(
                        fontFamily: 'PatrickHand',
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
            color: primaryColor,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 3,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: primaryColor,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  primaryColor.withValues(alpha: 0.1),
                  primaryColor.withValues(alpha: 0.0),
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

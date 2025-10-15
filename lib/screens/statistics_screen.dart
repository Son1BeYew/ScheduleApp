import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schedule_app/generated/app_localizations.dart';
import 'package:schedule_app/theme/app_colors.dart';
import 'package:schedule_app/theme/app_spacing.dart';
import 'package:schedule_app/theme/app_typography.dart';
import 'package:schedule_app/widgets/cards/app_card.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _stats = [];
  int _totalSchedules = 0;
  int _todaySchedules = 0;
  String _busiestDay = '';
  String _error = '';

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        setState(() {
          _isLoading = false;
          _error = 'Authentication token not found.';
        });
        return;
      }

      final url = Uri.parse('http://10.0.2.2:5000/api/schedules/stats/by-day');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final stats = data.map((item) => {'day': item['day'], 'count': item['count']}).toList();
        
        // Calculate summary
        int total = 0;
        int maxCount = 0;
        String busiest = '';
        
        for (var stat in stats) {
          final count = stat['count'] as int;
          total += count;
          if (count > maxCount) {
            maxCount = count;
            busiest = stat['day'];
          }
        }
        
        setState(() {
          _stats = stats;
          _totalSchedules = total;
          _busiestDay = busiest;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Failed to load statistics: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'An error occurred: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.statistics),
        automaticallyImplyLeading: false,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.screenPadding),
          child: AppCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 64, color: AppColors.error),
                SizedBox(height: AppSpacing.md),
                Text(_error, style: TextStyle(color: AppColors.error), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      );
    }

    if (_stats.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.screenPadding),
          child: AppCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bar_chart_outlined, size: 64, color: AppColors.textTertiary),
                SizedBox(height: AppSpacing.md),
                Text(
                  AppLocalizations.of(context)!.noDataAvailable,
                  style: TextStyle(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.screenPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSummaryCards(),
          SizedBox(height: AppSpacing.sectionSpacing),
          _buildChartCard(),
          SizedBox(height: AppSpacing.sectionSpacing),
          _buildDaysList(),
        ],
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        Expanded(
          child: AppCard(
            gradient: AppColors.gradientBlue,
            child: Column(
              children: [
                Icon(Icons.calendar_month, size: 32, color: AppColors.primary),
                SizedBox(height: AppSpacing.sm),
                Text(
                  _totalSchedules.toString(),
                  style: AppTypography.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Tổng lịch học',
                  style: AppTypography.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: AppSpacing.md),
        Expanded(
          child: AppCard(
            gradient: AppColors.gradientPurple,
            child: Column(
              children: [
                Icon(Icons.trending_up, size: 32, color: AppColors.secondary),
                SizedBox(height: AppSpacing.sm),
                Text(
                  _busiestDay,
                  style: AppTypography.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.secondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 4),
                Text(
                  'Ngày bận nhất',
                  style: AppTypography.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChartCard() {
    final maxValue = _stats.map((s) => s['count'] as int).reduce((a, b) => a > b ? a : b).toDouble();

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart, color: AppColors.primary),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lịch trình theo ngày',
                      style: AppTypography.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Số lượng lịch học trong tuần',
                      style: AppTypography.textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xl),
          SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _stats.map((s) => s['count'] as int).reduce((a, b) => a > b ? a : b).toDouble() + 2,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => AppColors.primary,
                    tooltipPadding: EdgeInsets.all(8),
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final stat = _stats[group.x.toInt()];
                      return BarTooltipItem(
                        '${stat['day']}\n${stat['count']} lịch học',
                        TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
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
                          getTitlesWidget: (double value, TitleMeta meta) {
                            final index = value.toInt();
                            if (index >= 0 && index < _stats.length) {
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                space: 4.0,
                                child: Text(
                                  _stats[index]['day'],
                                  style: AppTypography.textTheme.bodySmall,
                                ),
                              );
                            }
                            return Container();
                          },
                          reservedSize: 38,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 32,
                          getTitlesWidget: (value, meta) {
                            // Chỉ hiển thị số nguyên
                            if (value % 1 == 0) {
                              return Text(
                                value.toInt().toString(),
                                style: AppTypography.textTheme.bodySmall,
                              );
                            }
                            return Container();
                          },
                        ),
                      ),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 1,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(color: AppColors.border, strokeWidth: 1);
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: _stats.asMap().entries.map((entry) {
                  final index = entry.key;
                  final data = entry.value;
                  final count = data['count'] as int;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: count.toDouble(),
                        color: AppColors.primary,
                        width: 24,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primaryLight,
                          ],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ],
                    // Không hiện tooltip mặc định
                  );
                }).toList(),
              ),
            ),
          ),
          SizedBox(height: AppSpacing.md),
          Container(
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.infoLight,
              borderRadius: AppSpacing.borderRadiusMd,
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.info),
                SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Nhấn vào cột để xem chi tiết số lượng lịch học',
                    style: AppTypography.textTheme.bodySmall?.copyWith(
                      color: AppColors.info,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaysList() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.list_alt, color: AppColors.primary),
              SizedBox(width: AppSpacing.md),
              Text(
                'Chi tiết theo ngày',
                style: AppTypography.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          ..._stats.map((stat) {
            final day = stat['day'] as String;
            final count = stat['count'] as int;
            final percentage = (_totalSchedules > 0) 
                ? (count / _totalSchedules * 100).toStringAsFixed(1) 
                : '0.0';

            return Container(
              margin: EdgeInsets.only(bottom: AppSpacing.md),
              padding: EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: AppSpacing.borderRadiusLg,
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    child: Text(
                      day,
                      style: AppTypography.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        LinearProgressIndicator(
                          value: _totalSchedules > 0 ? count / _totalSchedules : 0,
                          backgroundColor: AppColors.border,
                          valueColor: AlwaysStoppedAnimation(AppColors.primary),
                          minHeight: 8,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '$percentage%',
                          style: AppTypography.textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: AppSpacing.borderRadiusSm,
                    ),
                    child: Text(
                      count.toString(),
                      style: AppTypography.textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
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

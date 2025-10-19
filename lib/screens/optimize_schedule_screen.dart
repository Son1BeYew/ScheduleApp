import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schedule_app/theme/app_colors.dart';
import 'package:schedule_app/theme/app_spacing.dart';
import 'package:schedule_app/theme/app_typography.dart';
import 'package:schedule_app/widgets/cards/app_card.dart';
import 'package:schedule_app/config/api_config.dart';

class OptimizeScheduleScreen extends StatefulWidget {
  const OptimizeScheduleScreen({super.key});

  @override
  State<OptimizeScheduleScreen> createState() => _OptimizeScheduleScreenState();
}

class _OptimizeScheduleScreenState extends State<OptimizeScheduleScreen> {
  final List<Subject> _subjects = [];
  final _nameController = TextEditingController();
  int _currentPriority = 3;
  String _startTime = '08:00';
  String _endTime = '10:00';
  bool _isOptimizing = false;
  bool _isApplying = false;
  Map<String, dynamic>? _suggestedSchedule;
  List<dynamic>? _remainingSubjects;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _selectStartTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(_startTime.split(':')[0]),
        minute: int.parse(_startTime.split(':')[1]),
      ),
    );
    if (picked != null) {
      setState(() {
        _startTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.parse(_endTime.split(':')[0]),
        minute: int.parse(_endTime.split(':')[1]),
      ),
    );
    if (picked != null) {
      setState(() {
        _endTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  void _addSubject() {
    if (_nameController.text.trim().isEmpty) return;

    // Validate time
    final start = TimeOfDay(
      hour: int.parse(_startTime.split(':')[0]),
      minute: int.parse(_startTime.split(':')[1]),
    );
    final end = TimeOfDay(
      hour: int.parse(_endTime.split(':')[0]),
      minute: int.parse(_endTime.split(':')[1]),
    );

    if (end.hour < start.hour || (end.hour == start.hour && end.minute <= start.minute)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thời gian kết thúc phải sau thời gian bắt đầu!')),
      );
      return;
    }

    setState(() {
      _subjects.add(Subject(
        name: _nameController.text.trim(),
        priority: _currentPriority,
        startTime: _startTime,
        endTime: _endTime,
      ));
      _nameController.clear();
      _currentPriority = 3;
      _startTime = '08:00';
      _endTime = '10:00';
    });
  }

  void _removeSubject(int index) {
    setState(() {
      _subjects.removeAt(index);
    });
  }

  Future<void> _optimizeSchedule() async {
    if (_subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng thêm ít nhất 1 môn học')),
      );
      return;
    }

    setState(() => _isOptimizing = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) throw Exception('Token not found');

      final response = await http.post(
        Uri.parse('${ApiConfig.apiSchedules}/optimize'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'subjects': _subjects.map((s) => s.toJson()).toList(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _suggestedSchedule = data['suggestedSchedule'];
          _remainingSubjects = data['remainingSubjects'];
        });
      } else {
        throw Exception('Failed to optimize: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isOptimizing = false);
      }
    }
  }

  Future<void> _applySchedule() async {
    if (_suggestedSchedule == null) return;

    setState(() => _isApplying = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) throw Exception('Token not found');

      final days = {
        'monday': 1,    // Thứ 2
        'tuesday': 2,   // Thứ 3
        'wednesday': 3, // Thứ 4
        'thursday': 4,  // Thứ 5
        'friday': 5,    // Thứ 6
      };

      // Get next Monday
      final now = DateTime.now();
      final daysUntilMonday = (DateTime.monday - now.weekday) % 7;
      final nextMonday = now.add(Duration(days: daysUntilMonday == 0 ? 7 : daysUntilMonday));

      int successCount = 0;
      int failCount = 0;

      for (var entry in days.entries) {
        final dayKey = entry.key;
        final dayOffset = entry.value - 1;
        final daySchedule = _suggestedSchedule![dayKey];
        final date = nextMonday.add(Duration(days: dayOffset));

        // Morning slot
        if (daySchedule['morning'] != null) {
          final subject = daySchedule['morning'];
          try {
            await http.post(
              Uri.parse(ApiConfig.apiSchedules),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: jsonEncode({
                'title': subject['name'],
                'date': date.toString().split(' ')[0],
                'time': subject['startTime'],
                'description': 'Auto-generated by Optimizer',
              }),
            );
            successCount++;
          } catch (e) {
            failCount++;
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã tạo $successCount lịch học thành công' +
                (failCount > 0 ? ', $failCount thất bại' : '')),
            backgroundColor: AppColors.success,
          ),
        );

        // Navigate back to schedule screen
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isApplying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tối ưu lịch học'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInfoCard(),
            SizedBox(height: AppSpacing.sectionSpacing),
            _buildAddSubjectForm(),
            SizedBox(height: AppSpacing.sectionSpacing),
            _buildSubjectsList(),
            SizedBox(height: AppSpacing.sectionSpacing),
            FilledButton.icon(
              onPressed: _isOptimizing || _subjects.isEmpty ? null : _optimizeSchedule,
              icon: _isOptimizing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(_isOptimizing ? 'Đang xử lý...' : 'Tối ưu lịch học'),
              style: FilledButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              ),
            ),
            if (_suggestedSchedule != null) ...[
              SizedBox(height: AppSpacing.sectionSpacing),
              _buildSuggestedSchedule(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return AppCard(
      gradient: AppColors.gradientBlue,
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: AppColors.primary),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Công cụ lập kế hoạch thông minh',
                  style: AppTypography.textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md),
          Text(
            '🎯 Cách sử dụng:\n'
            '1. Nhập danh sách môn học cần sắp xếp\n'
            '2. Đặt độ ưu tiên (1-5) cho mỗi môn\n'
            '3. Nhấn "Tối ưu lịch học" để xem gợi ý\n'
            '4. Sử dụng gợi ý để tạo lịch thủ công\n\n'
            '💡 Môn có priority cao sẽ được xếp vào slot đầu tiên (sáng Thứ 2)',
            style: AppTypography.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildAddSubjectForm() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Thêm môn học',
            style: AppTypography.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Tên môn học',
              hintText: 'VD: Toán học, Lập trình',
              prefixIcon: Icon(Icons.school_outlined),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addSubject(),
          ),
          SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: TextField(
                  readOnly: true,
                  onTap: _selectStartTime,
                  decoration: InputDecoration(
                    labelText: 'Giờ bắt đầu',
                    hintText: _startTime,
                    prefixIcon: const Icon(Icons.access_time),
                    border: const OutlineInputBorder(),
                  ),
                  controller: TextEditingController(text: _startTime),
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  readOnly: true,
                  onTap: _selectEndTime,
                  decoration: InputDecoration(
                    labelText: 'Giờ kết thúc',
                    hintText: _endTime,
                    prefixIcon: const Icon(Icons.access_time),
                    border: const OutlineInputBorder(),
                  ),
                  controller: TextEditingController(text: _endTime),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          Text(
            'Độ ưu tiên: $_currentPriority',
            style: AppTypography.textTheme.titleSmall,
          ),
          SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _currentPriority.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: _currentPriority.toString(),
                  onChanged: (value) {
                    setState(() => _currentPriority = value.toInt());
                  },
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Text(
                _getPriorityLabel(_currentPriority),
                style: AppTypography.textTheme.bodySmall?.copyWith(
                  color: _getPriorityColor(_currentPriority),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          OutlinedButton.icon(
            onPressed: _addSubject,
            icon: const Icon(Icons.add),
            label: const Text('Thêm môn học'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectsList() {
    if (_subjects.isEmpty) {
      return AppCard(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 48,
                  color: AppColors.textTertiary,
                ),
                SizedBox(height: AppSpacing.md),
                Text(
                  'Chưa có môn học nào',
                  style: AppTypography.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Danh sách môn học (${_subjects.length})',
            style: AppTypography.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          ...List.generate(_subjects.length, (index) {
            final subject = _subjects[index];
            return Container(
              margin: EdgeInsets.only(bottom: AppSpacing.md),
              padding: EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: AppSpacing.borderRadiusLg,
                border: Border.all(
                  color: _getPriorityColor(subject.priority).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: _getPriorityColor(subject.priority).withValues(alpha: 0.1),
                      borderRadius: AppSpacing.borderRadiusSm,
                    ),
                    child: Text(
                      subject.priority.toString(),
                      style: TextStyle(
                        color: _getPriorityColor(subject.priority),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject.name,
                          style: AppTypography.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 14, color: AppColors.textTertiary),
                            SizedBox(width: 4),
                            Text(
                              '${subject.startTime} - ${subject.endTime}',
                              style: AppTypography.textTheme.bodySmall?.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => _removeSubject(index),
                    color: AppColors.error,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSuggestedSchedule() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Lịch học đề xuất',
                  style: AppTypography.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.lg),
          ..._buildScheduleSlots(),
          if (_remainingSubjects != null && _remainingSubjects!.isNotEmpty) ...[
            SizedBox(height: AppSpacing.lg),
            Container(
              padding: EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: AppSpacing.borderRadiusMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Môn chưa sắp xếp được:',
                    style: AppTypography.textTheme.labelMedium?.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: AppSpacing.sm),
                  ..._remainingSubjects!.map((s) => Text(
                        '• ${s['name']}',
                        style: AppTypography.textTheme.bodySmall,
                      )),
                ],
              ),
            ),
          ],
          SizedBox(height: AppSpacing.lg),
          FilledButton.icon(
            onPressed: _isApplying ? null : _applySchedule,
            icon: _isApplying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check_circle),
            label: Text(_isApplying ? 'Đang tạo lịch...' : 'Áp dụng lịch này'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              backgroundColor: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildScheduleSlots() {
    final days = {
      'monday': 'Thứ 2',
      'tuesday': 'Thứ 3',
      'wednesday': 'Thứ 4',
      'thursday': 'Thứ 5',
      'friday': 'Thứ 6',
    };

    final slots = <Widget>[];

    days.forEach((key, label) {
      final daySchedule = _suggestedSchedule![key];
      final morning = daySchedule['morning'];
      final afternoon = daySchedule['afternoon'];

      slots.add(
        Container(
          margin: EdgeInsets.only(bottom: AppSpacing.md),
          padding: EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: AppSpacing.borderRadiusMd,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTypography.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _buildSlot('Sáng', morning),
                  ),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _buildSlot('Chiều', afternoon),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });

    return slots;
  }

  Widget _buildSlot(String label, dynamic subject) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: subject != null ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: AppSpacing.borderRadiusSm,
        border: Border.all(
          color: subject != null ? AppColors.primary.withValues(alpha: 0.3) : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.textTheme.labelSmall?.copyWith(
              color: AppColors.textTertiary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            subject != null ? subject['name'] : '---',
            style: AppTypography.textTheme.bodySmall?.copyWith(
              fontWeight: subject != null ? FontWeight.w600 : FontWeight.w400,
              color: subject != null ? AppColors.primary : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  String _getPriorityLabel(int priority) {
    switch (priority) {
      case 5:
        return 'Rất cao';
      case 4:
        return 'Cao';
      case 3:
        return 'Trung bình';
      case 2:
        return 'Thấp';
      case 1:
        return 'Rất thấp';
      default:
        return '';
    }
  }

  Color _getPriorityColor(int priority) {
    switch (priority) {
      case 5:
        return AppColors.error;
      case 4:
        return Colors.orange;
      case 3:
        return AppColors.warning;
      case 2:
        return AppColors.info;
      case 1:
        return AppColors.textTertiary;
      default:
        return AppColors.textSecondary;
    }
  }
}

class Subject {
  final String name;
  final int priority;
  final String startTime;
  final String endTime;

  Subject({
    required this.name, 
    required this.priority,
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'priority': priority,
        'startTime': startTime,
        'endTime': endTime,
      };
}

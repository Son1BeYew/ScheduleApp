import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schedule_app/generated/app_localizations.dart';
import 'package:schedule_app/config/api_config.dart';

class EditScheduleScreen extends StatefulWidget {
  final Map<String, dynamic>? schedule;

  const EditScheduleScreen({super.key, this.schedule});

  @override
  State<EditScheduleScreen> createState() => _EditScheduleScreenState();
}

class _EditScheduleScreenState extends State<EditScheduleScreen> {
  final _titleController = TextEditingController();
  final _timeController = TextEditingController();
  final _endTimeController = TextEditingController();
  final _descController = TextEditingController();
  final _dateController = TextEditingController();
  bool _loading = false;
  bool get _isEditing => widget.schedule != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _titleController.text = widget.schedule!['title'] ?? '';
      _timeController.text = widget.schedule!['time'] ?? '';
      _endTimeController.text = widget.schedule!['endTime'] ?? '';
      _descController.text = widget.schedule!['description'] ?? '';
      _dateController.text = widget.schedule!['date']?.toString().split('T')[0] ?? '';
    }
  }

  Future<void> _saveSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    setState(() => _loading = true);

    try {
      final body = jsonEncode({
        'title': _titleController.text,
        'time': _timeController.text,
        'endTime': _endTimeController.text,
        'description': _descController.text,
        'date': _dateController.text,
      });

      final response = _isEditing
          ? await http.put(
              Uri.parse('${ApiConfig.apiSchedules}/${widget.schedule!['_id']}'),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: body,
            )
          : await http.post(
              Uri.parse(ApiConfig.apiSchedules),
              headers: {
                'Authorization': 'Bearer $token',
                'Content-Type': 'application/json',
              },
              body: body,
            );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("${AppLocalizations.of(context)!.apiError}${response.statusCode}")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${AppLocalizations.of(context)!.connectionError}$e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateController.text.isNotEmpty
          ? DateTime.tryParse(_dateController.text) ?? DateTime.now()
          : DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _dateController.text = picked.toString().split(' ')[0]; // YYYY-MM-DD
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _timeController.text.isNotEmpty
          ? TimeOfDay(
              hour: int.tryParse(_timeController.text.split(':')[0]) ?? 0,
              minute: int.tryParse(_timeController.text.split(':')[1]) ?? 0,
            )
          : TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _timeController.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _selectEndTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _endTimeController.text.isNotEmpty
          ? TimeOfDay(
              hour: int.tryParse(_endTimeController.text.split(':')[0]) ?? 0,
              minute: int.tryParse(_endTimeController.text.split(':')[1]) ?? 0,
            )
          : TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _endTimeController.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? AppLocalizations.of(context)!.edit : 'Tạo lịch học mới',
          style: GoogleFonts.poppins(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.title,
                hintText: 'VD: Lập trình Di động',
                prefixIcon: const Icon(Icons.title),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _dateController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.date,
                hintText: 'Chọn ngày',
                prefixIcon: const Icon(Icons.calendar_today),
              ),
              readOnly: true,
              onTap: _selectDate,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _timeController,
              decoration: InputDecoration(
                labelText: 'Giờ bắt đầu',
                hintText: 'Chọn giờ bắt đầu',
                prefixIcon: const Icon(Icons.access_time),
              ),
              readOnly: true,
              onTap: _selectTime,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _endTimeController,
              decoration: const InputDecoration(
                labelText: 'Giờ kết thúc',
                hintText: 'Chọn giờ kết thúc',
                prefixIcon: Icon(Icons.schedule),
              ),
              readOnly: true,
              onTap: _selectEndTime,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.description,
                hintText: 'VD: Phòng A101',
                prefixIcon: const Icon(Icons.description),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loading ? null : _saveSchedule,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(AppLocalizations.of(context)!.save),
            ),
          ],
        ),
      ),
    );
  }
}

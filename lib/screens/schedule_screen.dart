import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schedule_app/generated/app_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'edit_schedule_screen.dart';
import 'optimize_schedule_screen.dart';
// removed unused import: google_fonts
// removed unused import: statistics_screen.dart

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  bool loading = true;
  bool _isExporting = false;
  List schedules = [];

  @override
  void initState() {
    super.initState();
    fetchSchedules();
  }

  String? _getUserIdFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) {
        return null;
      }
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final resp = utf8.decode(base64Url.decode(normalized));
      final payloadMap = json.decode(resp);
      return payloadMap['id'];
    } catch (e) {
      return null;
    }
  }

  Future<void> _exportSchedules() async {
    setState(() => _isExporting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        throw Exception('Token not found');
      }

      // Request storage permission (Android)
      if (Platform.isAndroid) {
        // Android 13+ không cần permission cho app-specific directory
        // Nhưng vẫn check cho Android 12 trở xuống
        if (await Permission.storage.isDenied) {
          final status = await Permission.storage.request();
          if (status.isDenied) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Không cần cấp quyền bộ nhớ. File sẽ lưu trong thư mục app.'),
                  duration: Duration(seconds: 3),
                ),
              );
            }
            // Continue anyway - use app-specific directory
          }
        }
      }

      // Call API to get .ics file
      final response = await http.get(
        Uri.parse('http://10.0.2.2:5000/api/schedules/export'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        // Get download directory  
        Directory? directory;
        if (Platform.isAndroid) {
          // Try to get Downloads directory, fallback to app directory
          directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            directory = await getExternalStorageDirectory();
          }
        } else {
          directory = await getApplicationDocumentsDirectory();
        }

        if (directory == null) {
          throw Exception('Could not get storage directory');
        }

        // Save file with friendly name
        final timestamp = DateTime.now();
        final filename = 'Lich_hoc_${timestamp.day}_${timestamp.month}_${timestamp.year}_${timestamp.hour}h${timestamp.minute}.ics';
        final filePath = '${directory.path}/$filename';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '✅ Xuất file thành công!',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('📁 $filename'),
                  const SizedBox(height: 4),
                  Text(
                    '📂 Lưu tại: ${Platform.isAndroid ? "Download" : "Documents"}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              duration: const Duration(seconds: 6),
              action: SnackBarAction(
                label: 'OK',
                onPressed: () {},
              ),
            ),
          );
        }
      } else {
        throw Exception('Failed to export: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> fetchSchedules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null) {
        // Handle not logged in case
        return;
      }

      final userId = _getUserIdFromToken(token);

      if (userId == null) {
        // Handle invalid token
        return;
      }

      final url = Uri.parse("http://10.0.2.2:5000/api/schedules/");
      final res = await http.get(url, headers: {
        'Authorization': 'Bearer $token',
      });

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          schedules = data;
          loading = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${AppLocalizations.of(context)!.apiError}${res.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${AppLocalizations.of(context)!.connectionError}$e")),
      );
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> _deleteSchedule(String scheduleId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    try {
      final url = Uri.parse('http://10.0.2.2:5000/api/schedules/$scheduleId');
      final response = await http.delete(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        fetchSchedules(); // Refresh the list
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${AppLocalizations.of(context)!.apiError}${response.statusCode}")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${AppLocalizations.of(context)!.connectionError}$e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.schedule),
        automaticallyImplyLeading: false, // We are in the main navigation flow
        actions: [
          IconButton(
            icon: _isExporting 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.file_download),
            tooltip: 'Xuất file .ics',
            onPressed: (schedules.isEmpty || _isExporting) ? null : _exportSchedules,
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Tối ưu lịch học',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const OptimizeScheduleScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : schedules.isEmpty
              ? _buildEmptyState()
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0),
                  child: ListView.builder(
                    itemCount: schedules.length,
                    itemBuilder: (context, index) {
                      final item = schedules[index];
                      final title = item["title"] ?? AppLocalizations.of(context)!.noTitle;
                      final time = item["time"] ?? "—";
                      final desc = item["description"] ?? "";
                      final date = item["date"]?.toString().split("T")[0] ?? "";
                      return _buildScheduleItem(item, time, title, desc, date);
                    },
                  ),
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const EditScheduleScreen(),
            ),
          );
          if (result == true) {
            fetchSchedules();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              'Chưa có lịch học',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Tạo lịch học mới bằng nút + bên dưới',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleItem(
    Map<String, dynamic> schedule,
    String time,
    String subject,
    String room,
    String date,
  ) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: ListTile(
        leading: Text(
          time,
          style: textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        title: Text(subject, style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500)),
        subtitle: Text("$room  |  $date", style: textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
        trailing: PopupMenuButton(
          onSelected: (value) async {
            if (value == 'edit') {
              final result = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (context) => EditScheduleScreen(schedule: schedule),
                ),
              );
              if (result == true) {
                fetchSchedules();
              }
            } else if (value == 'delete') {
              _deleteSchedule(schedule['_id']);
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Text(AppLocalizations.of(context)!.edit),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text(AppLocalizations.of(context)!.delete),
            ),
          ],
        ),
      ),
    );
  }
}

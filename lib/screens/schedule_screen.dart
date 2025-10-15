import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  bool loading = true;
  List schedules = [];

  @override
  void initState() {
    super.initState();
    fetchSchedules();
  }

  Future<void> fetchSchedules() async {
    try {
      // ⚠️ ID user thật (hoặc lấy từ token SharedPreferences)
      const userId = "68ee62c4778f224b7b17bbf9";

      final url = Uri.parse("http://10.0.2.2:5000/api/schedules/");
      final res = await http.get(url);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          schedules = data;
          loading = false;
        });
      } else {
        print("Lỗi API: ${res.statusCode}");
      }
    } catch (e) {
      print("Lỗi kết nối: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Thời Khóa Biểu",
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: schedules.length,
              itemBuilder: (context, index) {
                final item = schedules[index];
                final title = item["title"] ?? "—";
                final time = item["time"] ?? "—";
                final desc = item["description"] ?? "";
                final date = item["date"]?.toString().split("T")[0] ?? "";
                return _buildScheduleItem(time, title, desc, date);
              },
            ),
    );
  }

  Widget _buildScheduleItem(
    String time,
    String subject,
    String room,
    String date,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            time,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                subject,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                "$room  |  $date",
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

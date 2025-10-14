import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'schedule_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedTab = "today"; // today | schedule
  bool isLoggedIn = false; // trạng thái đăng nhập (giả lập)

  // === Chuyển giữa 2 tab ===
  void _onTabSelected(String tab, BuildContext context) {
    setState(() => selectedTab = tab);

    if (tab == "schedule") {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ScheduleScreen()),
      ).then((_) {
        // khi quay lại, đổi lại về "today"
        setState(() => selectedTab = "today");
      });
    }
  }

  // === Khi ấn avatar ===
  Future<void> _onAvatarTap(BuildContext context) async {
    if (isLoggedIn) {
      // Đã đăng nhập → Trang Cá Nhân
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ProfileScreen()),
      );
    } else {
      // Chưa đăng nhập → Trang Đăng Nhập
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      if (result == true) {
        setState(() => isLoggedIn = true); // cập nhật trạng thái
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Xin Chào,",
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.black54,
                        ),
                      ),
                      Text(
                        "Sơn",
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () => _onAvatarTap(context),
                    child: const CircleAvatar(
                      radius: 22,
                      backgroundImage: AssetImage('assets/images/avatar.jpg'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Toggle Hôm nay / Thời khóa biểu
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEFEFEF),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(
                  children: [
                    // Hôm nay
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _onTabSelected("today", context),
                        child: Container(
                          decoration: BoxDecoration(
                            color: selectedTab == "today"
                                ? Colors.black
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Center(
                            child: Text(
                              "Hôm nay",
                              style: GoogleFonts.poppins(
                                color: selectedTab == "today"
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Thời khóa biểu
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _onTabSelected("schedule", context),
                        child: Container(
                          decoration: BoxDecoration(
                            color: selectedTab == "schedule"
                                ? Colors.black
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Center(
                            child: Text(
                              "Thời Khóa Biểu",
                              style: GoogleFonts.poppins(
                                color: selectedTab == "schedule"
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Ngày tháng
              Text(
                "September 12,",
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                "Thursday",
                style: GoogleFonts.poppins(fontSize: 16, color: Colors.black54),
              ),

              const SizedBox(height: 24),

              // Weather card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Thời tiết",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "21°C",
                          style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          "Địa điểm\nTP.HCM",
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.black45,
                          ),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "Bình minh\n06:07",
                          textAlign: TextAlign.right,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Hoàng hôn\n17:59",
                          textAlign: TextAlign.right,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Ô tìm kiếm
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, color: Colors.grey[600]),
                    const SizedBox(width: 10),
                    Text(
                      "Tìm kiếm ghi chú, công việc...",
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              Text(
                "Công việc hôm nay",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 16),

              // Task 1
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFDFFFE0),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Nhóm",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        Row(
                          children: const [
                            CircleAvatar(
                              radius: 12,
                              backgroundImage: AssetImage(
                                'assets/images/user1.jpg',
                              ),
                            ),
                            SizedBox(width: 6),
                            CircleAvatar(
                              radius: 12,
                              backgroundImage: AssetImage(
                                'assets/images/user2.jpg',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Chia sẻ ghi chú nhóm",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "30 phút",
                          style: GoogleFonts.poppins(
                            fontSize: 26,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              "Bắt đầu 9:30 AM",
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                            Text(
                              "Kết thúc 10:00 AM",
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Task 2
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEFD5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Ghi chú nâng cao",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.black54,
                          ),
                        ),
                        Row(
                          children: const [
                            CircleAvatar(
                              radius: 12,
                              backgroundImage: AssetImage(
                                'assets/images/user3.jpg',
                              ),
                            ),
                            SizedBox(width: 6),
                            CircleAvatar(
                              radius: 12,
                              backgroundImage: AssetImage(
                                'assets/images/user4.jpg',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Client Meeting",
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),

      // Floating button
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: Colors.black,
        icon: const Icon(Icons.add, color: Colors.white),
        label: Text(
          "Ghi chú mới",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}

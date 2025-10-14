import 'package:flutter/material.dart';
import 'home_screen.dart'; // nếu bạn muốn chuyển thẳng vào Home
// import '../main.dart'; // nếu bạn muốn chuyển vào MainNavigation có bottom bar

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo + Title
              Column(
                children: [
                  const SizedBox(height: 40),
                  const Icon(
                    Icons.access_time,
                    size: 60,
                    color: Colors.black87,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "PlanMaster",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),

              // Illustration
              Expanded(
                child: Center(
                  child: Image.asset(
                    'assets/images/welcome.png',
                    height: 240,
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // Text
              const Column(
                children: [
                  Text(
                    "Simplify Your Schedule",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    "Tips and Tricks for Streamlined Scheduling",
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),

              // Button
              Padding(
                padding: const EdgeInsets.only(top: 32, bottom: 16),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      // 👉 Chuyển sang HomeScreen
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HomeScreen(),
                          // hoặc nếu bạn dùng bottom nav:
                          // builder: (context) => const MainNavigation(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Get Started",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

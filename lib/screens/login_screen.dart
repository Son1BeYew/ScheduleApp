import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _login() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // ⚠️ Dùng 10.0.2.2 khi chạy trên Android Emulator
      final url = Uri.parse('http://10.0.2.2:5000/api/auth/login');
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": _emailController.text.trim(),
          "password": _passwordController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // ✅ Lưu token để dùng cho các request sau
        final token = data["token"];
        print("Đăng nhập thành công, token: $token");

        // ✅ Trả kết quả về HomeScreen
        Navigator.pop(context, true);
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          _error = data["message"] ?? "Đăng nhập thất bại";
        });
      }
    } catch (e) {
      setState(() {
        _error = "Không thể kết nối server: $e";
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Đăng Nhập", style: GoogleFonts.poppins()),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Email", style: GoogleFonts.poppins(fontSize: 14)),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                hintText: "Nhập email...",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Text("Mật khẩu", style: GoogleFonts.poppins(fontSize: 14)),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: "Nhập mật khẩu...",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),

            if (_error != null)
              Text(
                _error!,
                style: GoogleFonts.poppins(color: Colors.red, fontSize: 13),
              ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading ? null : _login,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        "Đăng Nhập",
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

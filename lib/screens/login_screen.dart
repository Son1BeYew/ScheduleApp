import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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

        // Lấy token
        final String? token = data["token"]?.toString();

        // Cố gắng lấy tên theo nhiều cách an toàn
        String? name = _extractNameFromResponse(data);
        name ??= _decodeNameFromJwt(token);
        name ??= _fallbackNameFromEmail(_emailController.text.trim());

        // Lưu token & tên để dùng sau
        final prefs = await SharedPreferences.getInstance();
        if (token != null) await prefs.setString('auth_token', token);
        if (name != null) await prefs.setString('user_name', name);

        // Trả tên về HomeScreen để hiển thị
        Navigator.pop(context, name ?? 'Bạn');
      } else {
        final data = _safeJson(response.body);
        setState(() {
          _error = (data?["message"]?.toString() ?? "Đăng nhập thất bại")
              .toString();
        });
      }
    } catch (e) {
      setState(() {
        _error = "Không thể kết nối server: $e";
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic>? _safeJson(String body) {
    try {
      final parsed = jsonDecode(body);
      if (parsed is Map<String, dynamic>) return parsed;
    } catch (_) {}
    return null;
  }

  /// Ưu tiên lấy từ `data.user.name`, rồi `fullName`, `username`, hoặc `data.name`
  String? _extractNameFromResponse(Map<String, dynamic> data) {
    String? tryPick(Map m) {
      for (final key in ['name', 'fullName', 'username']) {
        if (m[key] != null && m[key].toString().trim().isNotEmpty) {
          return _prettify(m[key].toString());
        }
      }
      return null;
    }

    if (data['user'] is Map) {
      final v = tryPick(data['user'] as Map);
      if (v != null) return v;
    }
    if (data['data'] is Map) {
      final v = tryPick(data['data'] as Map);
      if (v != null) return v;
    }
    if (data['name'] != null) {
      return _prettify(data['name'].toString());
    }
    return null;
  }

  /// Giải mã JWT (phần payload) để lấy các field tên phổ biến
  String? _decodeNameFromJwt(String? token) {
    if (token == null) return null;
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      String normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized)));
      if (payload is! Map) return null;

      for (final key in ['name', 'fullName', 'username', 'given_name']) {
        if (payload[key] != null && payload[key].toString().trim().isNotEmpty) {
          return _prettify(payload[key].toString());
        }
      }
    } catch (_) {}
    return null;
  }

  /// Nếu không có gì cả, lấy tên từ email (phần trước @)
  String _fallbackNameFromEmail(String email) {
    final local = (email.contains('@') ? email.split('@').first : email).trim();
    return _prettify(local.isEmpty ? 'Bạn' : local);
  }

  String _prettify(String s) {
    if (s.isEmpty) return 'Bạn';
    final t = s.trim();
    if (t.length == 1) return t.toUpperCase();
    return t[0].toUpperCase() + t.substring(1);
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

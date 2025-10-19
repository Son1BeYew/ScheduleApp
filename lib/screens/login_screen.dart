import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:schedule_app/generated/app_localizations.dart';
import 'package:schedule_app/config/api_config.dart';

import '../main.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _googleLoading = false;
  bool _obscure = true;
  String? _error;

  // TODO: thay bằng Web Client ID của bạn
  final webClientId = dotenv.env['WEB_CLIENT_ID']!;
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final url = Uri.parse('${ApiConfig.apiAuth}/login');
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
        final token = data["token"];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);

        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainNavigation()),
          (route) => false,
        );
      } else {
        final data = jsonDecode(response.body);
        final errorMessage =
            data["message"] ?? AppLocalizations.of(context)!.loginFailed;
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "${AppLocalizations.of(context)!.serverConnectionError}$e",
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() {
      _googleLoading = true;
      _error = null;
    });

    try {
      final googleSignIn = GoogleSignIn(
        serverClientId: webClientId, // <-- lấy từ .env
        scopes: ['email', 'profile'],
      );

      final account = await googleSignIn.signIn();
      if (account == null) {
        setState(() => _googleLoading = false);
        return; // user hủy
      }

      final auth = await account!.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        throw Exception('Không lấy được Google ID Token');
      }

      final resp = await http.post(
        Uri.parse('${ApiConfig.apiAuth}/google-login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'idToken': idToken}),
      );

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final jwt = data['token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', jwt);

        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainNavigation()),
          (route) => false,
        );
      } else {
        final data = jsonDecode(resp.body);
        final msg = data['message'] ?? 'Đăng nhập Google thất bại';
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Google Sign-In lỗi: $e')));
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE6E6E6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.black),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context)!;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF6F7FB), Color(0xFFEFF3FF)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Logo / Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.schedule, size: 32),
                        const SizedBox(width: 8),
                        Text(
                          'Schedule App',
                          style: GoogleFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x11000000),
                            blurRadius: 16,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(20),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              t.login,
                              style: GoogleFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),

                            // Email
                            Text(
                              t.email,
                              style: GoogleFonts.poppins(fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              decoration: _inputDecoration(
                                hint: t.enterEmailHint,
                                icon: Icons.email_outlined,
                              ),
                              validator: (v) {
                                final value = v?.trim() ?? '';
                                if (value.isEmpty) return t.enterEmailHint;
                                final emailReg = RegExp(
                                  r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                                );
                                if (!emailReg.hasMatch(value)) {
                                  return t.enterEmailHint;
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),

                            // Password
                            Text(
                              t.password,
                              style: GoogleFonts.poppins(fontSize: 13),
                            ),
                            const SizedBox(height: 6),
                            TextFormField(
                              controller: _passwordController,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _login(),
                              decoration: _inputDecoration(
                                hint: t.enterPasswordHint,
                                icon: Icons.lock_outline,
                                suffix: IconButton(
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                ),
                              ),
                              validator: (v) {
                                final value = v?.trim() ?? '';
                                if (value.isEmpty) return t.enterPasswordHint;
                                if (value.length < 6) {
                                  return t
                                      .loginFailed; // hoặc tạo text riêng “Mật khẩu tối thiểu 6 ký tự”
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 20),

                            // Login button
                            SizedBox(
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _loading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                child: _loading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.6,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        t.login,
                                        style: GoogleFonts.poppins(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 16),

                            // OR divider
                            Row(
                              children: [
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: const Color(0xFFE6E6E6),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  child: Text(
                                    'hoặc',
                                    style: GoogleFonts.poppins(
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 1,
                                    color: const Color(0xFFE6E6E6),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Google button
                            SizedBox(
                              height: 52,
                              child: OutlinedButton.icon(
                                onPressed: _googleLoading
                                    ? null
                                    : _loginWithGoogle,
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: Color(0xFFE6E6E6),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  backgroundColor: Colors.white,
                                ),
                                icon: _googleLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.g_mobiledata, size: 28),
                                label: Text(
                                  'Đăng nhập với Google',
                                  style: GoogleFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Register
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(t.noAccount, style: GoogleFonts.poppins()),
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterScreen(),
                              ),
                            );
                          },
                          child: Text(
                            t.register,
                            style: GoogleFonts.poppins(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(color: Colors.red),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

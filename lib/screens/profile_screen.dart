import 'dart:convert';
// removed unused import: dart:io

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:schedule_app/generated/app_localizations.dart';
import 'package:schedule_app/config/api_config.dart';
import 'package:schedule_app/services/socket_service.dart';

import '../main.dart';
import 'welcome_screen.dart';
import 'edit_profile_screen.dart';
import 'admin_dashboard_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _loading = true;
  String _name = "";
  String _email = "";
  String _avatar = "";
  String _createdAt = "";
  String _role = "user";

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  String? _getUserIdFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final resp = utf8.decode(base64Url.decode(normalized));
      final payloadMap = json.decode(resp);
      return payloadMap['id'];
    } catch (e) {
      return null;
    }
  }

  Future<void> _fetchUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) {
      setState(() => _loading = false);
      return;
    }

    final userId = _getUserIdFromToken(token);
    if (userId == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      final url = Uri.parse('${ApiConfig.apiUsers}/$userId');
      final response = await http.get(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _name = data['name'] ?? '';
          _email = data['email'] ?? '';
          _avatar = data['avatar'] ?? '';
          _createdAt = data['createdAt']?.toString().split('T')[0] ?? '';
          _role = data['role'] ?? 'user';
          _loading = false;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${AppLocalizations.of(context)!.apiError}${response.statusCode}")),
        );
        setState(() => _loading = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("${AppLocalizations.of(context)!.connectionError}$e")),
      );
      setState(() => _loading = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return;

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    final request = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.apiUsers}/avatar'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(await http.MultipartFile.fromPath('avatar', pickedFile.path));

    try {
      final response = await request.send();
      if (response.statusCode == 200) {
        _fetchUserData(); // Refresh profile
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

  void _changeLanguage(Locale locale) {
    MyApp.setLocale(context, locale);
    
    // Show confirmation with snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          locale.languageCode == 'vi' 
            ? 'Đã đổi sang Tiếng Việt. Đang tải lại...' 
            : 'Changed to English. Reloading...'
        ),
        duration: const Duration(seconds: 1),
      ),
    );
    
    // Reload the current screen after a short delay
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          _loading = true;
        });
        _fetchUserData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(
          AppLocalizations.of(context)!.profile,
          style: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickAndUploadAvatar,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: _avatar.isNotEmpty
                          ? NetworkImage(ApiConfig.getEndpoint(_avatar))
                          : const AssetImage('images/avatar.png') as ImageProvider,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    "${AppLocalizations.of(context)!.hello} $_name",
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 30),
                  _buildInfoCard(
                    title: AppLocalizations.of(context)!.name,
                    value: _name,
                    icon: Icons.person_outline,
                  ),
                  _buildInfoCard(
                    title: AppLocalizations.of(context)!.email,
                    value: _email,
                    icon: Icons.email_outlined,
                  ),
                  _buildInfoCard(
                    title: AppLocalizations.of(context)!.password,
                    value: "********",
                    icon: Icons.lock_outline,
                  ),
                  _buildInfoCard(
                    title: AppLocalizations.of(context)!.accountCreationDate,
                    value: _createdAt,
                    icon: Icons.calendar_today_outlined,
                  ),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(onPressed: () => _changeLanguage(const Locale('en')), child: Text(AppLocalizations.of(context)!.english)),
                      const SizedBox(width: 20),
                      ElevatedButton(onPressed: () => _changeLanguage(const Locale('vi')), child: Text(AppLocalizations.of(context)!.vietnamese)),
                    ],
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => EditProfileScreen(
                              currentName: _name,
                              currentEmail: _email,
                            ),
                          ),
                        );
                        if (result == true && mounted) {
                          _fetchUserData(); // Reload profile after update
                        }
                      },
                      icon: const Icon(Icons.edit, color: Colors.white),
                      label: Text(
                        AppLocalizations.of(context)!.editProfile,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Admin Dashboard Button (only for admin)
                  if (_role == 'admin') ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
                        ),
                        icon: const Icon(Icons.admin_panel_settings),
                        label: Text(
                          'Admin Dashboard',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      onPressed: () => _showLogoutDialog(context),
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: Text(
                        AppLocalizations.of(context)!.logout,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.red,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.black54, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isNotEmpty ? value : "—",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          AppLocalizations.of(context)!.logout,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          AppLocalizations.of(context)!.logoutConfirmation,
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.cancel, style: GoogleFonts.poppins(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _logout();
            },
            child: Text(
              AppLocalizations.of(context)!.logout,
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    print('🔴 Logging out...');
    
    // Disconnect socket
    final socketService = SocketService();
    socketService.disconnect();
    print('✅ Socket disconnected');
    
    // Clear token
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    print('✅ Token removed');

    if (!mounted) return;
    // Navigate to welcome screen
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      (route) => false,
    );
  }
}

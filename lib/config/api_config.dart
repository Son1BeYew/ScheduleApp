class ApiConfig {
  // TODO: Update this URL when using ngrok
  // For emulator: use 'http://10.0.2.2:5000'
  // For real device with ngrok: use 'https://YOUR_NGROK_URL.ngrok-free.app'

  static const String baseUrl = 'http://10.0.2.2:5000';

  
  // API endpoints
  static const String apiNotes = '$baseUrl/api/notes';
  static const String apiGroups = '$baseUrl/api/groups';
  static const String apiAuth = '$baseUrl/api/auth';
  static const String apiUsers = '$baseUrl/api/users';
  static const String apiSchedules = '$baseUrl/api/schedules';
  
  // Socket.IO URL (remove /api path)
  static const String socketUrl = baseUrl;
  
  // Helper to get full endpoint or asset URL
  static String getEndpoint(String path) {
    if (path.startsWith('http')) return path;

    if (path.startsWith('/')) return '$baseUrl$path';
    return '$baseUrl/$path';
  }
}

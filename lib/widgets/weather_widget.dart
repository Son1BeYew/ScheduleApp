import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:schedule_app/theme/app_colors.dart';
import 'package:schedule_app/theme/app_spacing.dart';
import 'package:schedule_app/theme/app_typography.dart';

class WeatherWidget extends StatefulWidget {
  const WeatherWidget({super.key});

  @override
  State<WeatherWidget> createState() => _WeatherWidgetState();
}

class _WeatherWidgetState extends State<WeatherWidget> {
  bool _loading = true;
  String _city = '';
  double _temp = 0;
  String _description = '';
  String _icon = '';
  String? _error;

  // OpenWeatherMap API key - FREE tier
  // Get your free API key at: https://openweathermap.org/api
  // TODO: Replace with your own API key
  static const String _apiKey = 'YOUR_API_KEY_HERE'; // Replace this!
  
  // TEMPORARY: Use mock data for testing (set to false when have real API key)
  static const bool _useMockData = true;
  
  @override
  void initState() {
    super.initState();
    if (_useMockData) {
      _loadMockData();
    } else {
      _fetchWeather();
    }
  }

  void _loadMockData() {
    // Simulate API delay
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _city = 'Ha Noi';
          _temp = 28.5;
          _description = 'Trời nắng, ít mây';
          _icon = '01d';
          _loading = false;
        });
      }
    });
  }

  Future<void> _fetchWeather() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _error = 'Cần cấp quyền vị trí';
            _loading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _error = 'Quyền vị trí bị từ chối';
          _loading = false;
        });
        return;
      }

      // Get current location
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );

      // Fetch weather from OpenWeatherMap
      final url = Uri.parse(
        'https://api.openweathermap.org/data/2.5/weather?lat=${position.latitude}&lon=${position.longitude}&appid=$_apiKey&units=metric&lang=vi',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (mounted) {
          setState(() {
            _city = data['name'] ?? 'Unknown';
            _temp = (data['main']['temp'] as num).toDouble();
            _description = data['weather'][0]['description'] ?? '';
            _icon = data['weather'][0]['icon'] ?? '01d';
            _loading = false;
          });
        }
      } else {
        throw Exception('Failed to load weather');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Không thể tải thời tiết';
          _loading = false;
        });
      }
    }
  }

  String _getWeatherIcon(String icon) {
    // Map OpenWeatherMap icons to emoji
    if (icon.startsWith('01')) return '☀️'; // clear
    if (icon.startsWith('02')) return '⛅'; // few clouds
    if (icon.startsWith('03')) return '☁️'; // scattered clouds
    if (icon.startsWith('04')) return '☁️'; // broken clouds
    if (icon.startsWith('09')) return '🌧️'; // shower rain
    if (icon.startsWith('10')) return '🌦️'; // rain
    if (icon.startsWith('11')) return '⛈️'; // thunderstorm
    if (icon.startsWith('13')) return '❄️'; // snow
    if (icon.startsWith('50')) return '🌫️'; // mist
    return '🌤️';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0.8),
              AppColors.primary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            ),
            SizedBox(width: AppSpacing.sm),
            Text(
              'Đang tải thời tiết...',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.error.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: AppColors.error, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                _error!,
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 14,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh, size: 20),
              onPressed: _fetchWeather,
              color: AppColors.error,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.8),
            AppColors.primary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            _getWeatherIcon(_icon),
            style: const TextStyle(fontSize: 48),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_temp.round()}°C',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.white70,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _city,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchWeather,
          ),
        ],
      ),
    );
  }
}

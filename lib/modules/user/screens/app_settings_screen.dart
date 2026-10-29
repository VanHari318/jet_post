import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_logger.dart';
import '../../../routes/app_routes.dart';
import '../../driver/services/driver_order_preferences.dart';

/// Màn hình Cài đặt Ứng dụng & Tùy chọn Trải nghiệm (App Settings Screen)
/// Tùy biến Theme Sáng/Tối, Cấu hình Âm thanh & Rung, Demo Role Switcher
class AppSettingsScreen extends StatefulWidget {
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  const AppSettingsScreen({super.key, this.onThemeModeChanged});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  String _themeMode = 'system'; // 'light', 'dark', 'system'
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await DriverOrderPreferences.instance.load();
    if (!mounted) return;
    setState(() {
      _themeMode = prefs.getString(AppTheme.prefThemeKey) ?? 'system';
      _soundEnabled = prefs.getBool('pref_sound_enabled') ?? true;
      _vibrationEnabled = prefs.getBool('pref_vibration_enabled') ?? true;
    });
  }

  Future<void> _saveDriverOrderPreferences(
    DriverOrderPreferencesValue updated,
  ) async {
    try {
      await DriverOrderPreferences.instance.update(updated);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể lưu cài đặt nhận đơn: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _saveThemeMode(String mode) async {
    AppLogger.settings('Giao diện (Theme Mode)', mode);
    setState(() => _themeMode = mode);
    await AppTheme.setThemeMode(mode);
    widget.onThemeModeChanged?.call(AppTheme.themeModeNotifier.value);
  }

  Future<void> _toggleSound(bool val) async {
    AppLogger.settings('Chuông báo cuốc xe', val ? 'Bật' : 'Tắt');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pref_sound_enabled', val);
    setState(() => _soundEnabled = val);
  }

  Future<void> _toggleVibration(bool val) async {
    AppLogger.settings('Rung khi có thông báo', val ? 'Bật' : 'Tắt');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('pref_vibration_enabled', val);
    setState(() => _vibrationEnabled = val);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Cài Đặt Ứng Dụng')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // NHÓM 1: GIAO DIỆN & HIỂN THỊ
            _buildSectionHeader(context, 'GIAO DIỆN & HIỂN THỊ (THEME)'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: RadioGroup<String>(
                groupValue: _themeMode,
                onChanged: (val) {
                  if (val != null) _saveThemeMode(val);
                },
                child: Column(
                  children: const [
                    RadioListTile<String>(
                      title: Text('Theo hệ điều hành (System)'),
                      subtitle: Text('Tự động đổi theo cài đặt của máy'),
                      value: 'system',
                      secondary: Icon(
                        Icons.brightness_auto,
                        color: AppColors.primary,
                      ),
                    ),
                    Divider(height: 1),
                    RadioListTile<String>(
                      title: Text('Giao diện Sáng (Light Mode)'),
                      subtitle: Text('Tối ưu nhìn ngoài trời ban ngày'),
                      value: 'light',
                      secondary: Icon(
                        Icons.light_mode,
                        color: Color(0xFFFFB300),
                      ),
                    ),
                    Divider(height: 1),
                    RadioListTile<String>(
                      title: Text('Giao diện Tối (Dark Mode)'),
                      subtitle: Text('Dịu mắt khi tài xế chạy xe ban đêm'),
                      value: 'dark',
                      secondary: Icon(
                        Icons.dark_mode,
                        color: Color(0xFF7E57C2),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // NHÓM 2: ÂM THANH & RUNG
            _buildSectionHeader(context, 'ÂM THANH & THÔNG BÁO CUỐC XE'),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                ),
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Chuông báo cuốc xe mới'),
                    subtitle: const Text(
                      'Phát chuông lớn khi có cuốc trong bán kính 15s',
                    ),
                    value: _soundEnabled,
                    activeThumbColor: AppColors.primary,
                    secondary: const Icon(
                      Icons.volume_up_outlined,
                      color: AppColors.primary,
                    ),
                    onChanged: _toggleSound,
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Rung khi có thông báo'),
                    subtitle: const Text(
                      'Rung điện thoại khi nhận đơn hàng hoặc tin nhắn',
                    ),
                    value: _vibrationEnabled,
                    activeThumbColor: AppColors.primary,
                    secondary: const Icon(
                      Icons.vibration,
                      color: AppColors.primary,
                    ),
                    onChanged: _toggleVibration,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            _buildSectionHeader(context, 'PHƯƠNG THỨC NHẬN ĐƠN'),
            const SizedBox(height: 10),
            _buildDriverOrderPreferences(isDark),

            const SizedBox(height: 24),

            // NHÓM 3: DEMO ROLE SWITCHER (CHẤM ĐIỂM HỘI ĐỒNG)
            _buildSectionHeader(
              context,
              'CÔNG CỤ DEMO CHẤM ĐIỂM (ROLE SWITCHER)',
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withAlpha(80)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.swap_calls,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Chuyển nhanh vai trò kiểm thử',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Phục vụ các thành viên nhóm và Giảng viên chuyển đổi nhanh vào các phân hệ độc lập:',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF00A86B)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () {
                            AppLogger.userAction(
                              'Settings',
                              'Demo Role Switcher ➔ Khách hàng',
                            );
                            Navigator.pushNamed(
                              context,
                              AppRoutes.customerHome,
                            );
                          },
                          child: const Text(
                            'Khách hàng',
                            style: TextStyle(
                              color: Color(0xFF00A86B),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFF6B00)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () {
                            AppLogger.userAction(
                              'Settings',
                              'Demo Role Switcher ➔ Tài xế',
                            );
                            Navigator.pushNamed(
                              context,
                              AppRoutes.driverDashboard,
                            );
                          },
                          child: const Text(
                            'Tài xế',
                            style: TextStyle(
                              color: Color(0xFFFF6B00),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF1E88E5)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                          onPressed: () {
                            AppLogger.userAction(
                              'Settings',
                              'Demo Role Switcher ➔ Admin',
                            );
                            Navigator.pushNamed(
                              context,
                              AppRoutes.adminDashboard,
                            );
                          },
                          child: const Text(
                            'Admin',
                            style: TextStyle(
                              color: Color(0xFF1E88E5),
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // THÔNG TIN ĐỒ ÁN
            Center(
              child: Column(
                children: [
                  Text(
                    AppStrings.appName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Phiên bản 1.0.0 (Build 2026) - Đồ án Chuyên đề CNTT Nhóm 14',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textMutedDark
                          : AppColors.textMutedLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Trường Đại học Thủy Lợi (TLU)',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textMutedDark
                          : AppColors.textMutedLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverOrderPreferences(bool isDark) {
    return ValueListenableBuilder<DriverOrderPreferencesValue>(
      valueListenable: DriverOrderPreferences.instance.value,
      builder: (context, preferences, _) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: Column(
            children: [
              _buildOrderTypeSettings(
                title: 'Cuốc xe',
                icon: Icons.motorcycle_rounded,
                enabled: preferences.autoAcceptRides,
                distance: preferences.rideMaxDistanceKm,
                distanceOptions: const [5, 7, 0],
                distanceLabels: const ['< 5 km', '< 7 km', 'Không giới hạn'],
                onEnabledChanged: (enabled) => _saveDriverOrderPreferences(
                  preferences.copyWith(autoAcceptRides: enabled),
                ),
                onDistanceChanged: (distance) => _saveDriverOrderPreferences(
                  preferences.copyWith(rideMaxDistanceKm: distance),
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              _buildOrderTypeSettings(
                title: 'Giao hàng',
                icon: Icons.local_shipping_rounded,
                enabled: preferences.autoAcceptDeliveries,
                distance: preferences.deliveryMaxDistanceKm,
                distanceOptions: const [5, 7, 0],
                distanceLabels: const ['< 5 km', '< 7 km', 'Không giới hạn'],
                onEnabledChanged: (enabled) => _saveDriverOrderPreferences(
                  preferences.copyWith(autoAcceptDeliveries: enabled),
                ),
                onDistanceChanged: (distance) => _saveDriverOrderPreferences(
                  preferences.copyWith(deliveryMaxDistanceKm: distance),
                ),
                codLimit: preferences.deliveryCodLimit,
                onCodLimitChanged: (limit) => _saveDriverOrderPreferences(
                  preferences.copyWith(deliveryCodLimit: limit),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderTypeSettings({
    required String title,
    required IconData icon,
    required bool enabled,
    required double distance,
    required List<double> distanceOptions,
    required List<String> distanceLabels,
    required ValueChanged<bool> onEnabledChanged,
    required ValueChanged<double> onDistanceChanged,
    double? codLimit,
    ValueChanged<double>? onCodLimitChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          SwitchListTile(
            secondary: Icon(icon, color: AppColors.primary),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: const Text('Tự động nhận đơn phù hợp'),
            value: enabled,
            activeThumbColor: AppColors.primary,
            onChanged: onEnabledChanged,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Expanded(child: Text('Khoảng cách nhận đơn')),
                DropdownButton<double>(
                  value: distance,
                  items: List.generate(
                    distanceOptions.length,
                    (index) => DropdownMenuItem(
                      value: distanceOptions[index],
                      child: Text(distanceLabels[index]),
                    ),
                  ),
                  onChanged: (value) {
                    if (value != null) onDistanceChanged(value);
                  },
                ),
              ],
            ),
          ),
          if (codLimit != null && onCodLimitChanged != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  const Expanded(child: Text('Giới hạn tiền ứng COD')),
                  DropdownButton<double>(
                    value: codLimit,
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Không giới hạn')),
                      DropdownMenuItem(value: 500000, child: Text('< 500k')),
                      DropdownMenuItem(value: 1000000, child: Text('< 1tr')),
                      DropdownMenuItem(value: 2000000, child: Text('< 2tr')),
                    ],
                    onChanged: (value) {
                      if (value != null) onCodLimitChanged(value);
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
          color: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
        ),
      ),
    );
  }
}

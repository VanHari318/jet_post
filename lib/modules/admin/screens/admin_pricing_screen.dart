import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../models/system_settings_model.dart';
import '../controllers/admin_controller.dart';

/// Task 4.6 - Cấu hình Biểu cước & Chính sách Hệ thống
class AdminPricingScreen extends StatefulWidget {
  final String adminId;

  const AdminPricingScreen({super.key, required this.adminId});

  @override
  State<AdminPricingScreen> createState() => _AdminPricingScreenState();
}

class _AdminPricingScreenState extends State<AdminPricingScreen> {
  final _controller = AdminController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSaving = false;
  SystemSettingsModel? _settings;

  // Controllers cho từng tham số
  late TextEditingController _basePriceRideCtrl;
  late TextEditingController _pricePerKmRideCtrl;
  late TextEditingController _basePriceDeliveryCtrl;
  late TextEditingController _pricePerKmDeliveryCtrl;
  late TextEditingController _commissionCtrl;
  late TextEditingController _maxRadiusCtrl;
  late TextEditingController _driverTimeoutCtrl;
  late TextEditingController _radarTimeoutCtrl;

  @override
  void initState() {
    super.initState();
    _initControllers();
    _loadSettings();
  }

  void _initControllers() {
    _basePriceRideCtrl = TextEditingController();
    _pricePerKmRideCtrl = TextEditingController();
    _basePriceDeliveryCtrl = TextEditingController();
    _pricePerKmDeliveryCtrl = TextEditingController();
    _commissionCtrl = TextEditingController();
    _maxRadiusCtrl = TextEditingController();
    _driverTimeoutCtrl = TextEditingController();
    _radarTimeoutCtrl = TextEditingController();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    final settings = await _controller.getSystemSettings();
    setState(() {
      _settings = settings;
      _isLoading = false;
    });

    if (settings != null) {
      _basePriceRideCtrl.text = settings.basePriceRide.toStringAsFixed(0);
      _pricePerKmRideCtrl.text = settings.pricePerKmRide.toStringAsFixed(0);
      _basePriceDeliveryCtrl.text =
          settings.basePriceDelivery.toStringAsFixed(0);
      _pricePerKmDeliveryCtrl.text =
          settings.pricePerKmDelivery.toStringAsFixed(0);
      _commissionCtrl.text =
          (settings.commissionRate * 100).toStringAsFixed(0);
      _maxRadiusCtrl.text = settings.maxSearchRadiusKm.toStringAsFixed(1);
      _driverTimeoutCtrl.text =
          settings.driverAcceptTimeoutSeconds.toString();
      _radarTimeoutCtrl.text =
          settings.radarSearchTimeoutSeconds.toString();
    } else {
      // Giá trị mặc định theo KeHoach.md
      _basePriceRideCtrl.text = '15000';
      _pricePerKmRideCtrl.text = '6000';
      _basePriceDeliveryCtrl.text = '18000';
      _pricePerKmDeliveryCtrl.text = '7000';
      _commissionCtrl.text = '15';
      _maxRadiusCtrl.text = '5.0';
      _driverTimeoutCtrl.text = '15';
      _radarTimeoutCtrl.text = '45';
    }
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final newSettings = SystemSettingsModel(
        basePriceRide: double.parse(_basePriceRideCtrl.text),
        pricePerKmRide: double.parse(_pricePerKmRideCtrl.text),
        basePriceDelivery: double.parse(_basePriceDeliveryCtrl.text),
        pricePerKmDelivery: double.parse(_pricePerKmDeliveryCtrl.text),
        commissionRate: double.parse(_commissionCtrl.text) / 100,
        maxSearchRadiusKm: double.parse(_maxRadiusCtrl.text),
        driverAcceptTimeoutSeconds: int.parse(_driverTimeoutCtrl.text),
        radarSearchTimeoutSeconds: int.parse(_radarTimeoutCtrl.text),
        updatedAt: DateTime.now(),
        updatedBy: widget.adminId,
      );

      await _controller.saveSystemSettings(
        settings: newSettings,
        adminId: widget.adminId,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              '✅ Đã lưu cấu hình! Tất cả máy khách tự động cập nhật giá mới.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      setState(() => _isSaving = false);
    } catch (e) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi lưu cấu hình: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _basePriceRideCtrl.dispose();
    _pricePerKmRideCtrl.dispose();
    _basePriceDeliveryCtrl.dispose();
    _pricePerKmDeliveryCtrl.dispose();
    _commissionCtrl.dispose();
    _maxRadiusCtrl.dispose();
    _driverTimeoutCtrl.dispose();
    _radarTimeoutCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cấu hình Biểu cước'),
        backgroundColor: AppColors.secondary,
        foregroundColor: Colors.white,
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Info banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.infoBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.info.withOpacity(0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: AppColors.info, size: 18),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Thay đổi sẽ áp dụng ngay lập tức cho tất cả tính cước tiếp theo mà không cần update app.',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.info),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Biểu cước Xe ôm
                    _PricingSection(
                      title: '🏍 Biểu cước Xe ôm',
                      color: AppColors.primary,
                      children: [
                        _PriceField(
                          label: 'Giá mở cửa (0-2km đầu)',
                          controller: _basePriceRideCtrl,
                          unit: 'đ',
                          hint: '15000',
                        ),
                        _PriceField(
                          label: 'Giá mỗi km tiếp theo',
                          controller: _pricePerKmRideCtrl,
                          unit: 'đ/km',
                          hint: '6000',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Biểu cước Giao hàng
                    _PricingSection(
                      title: '📦 Biểu cước Giao hàng',
                      color: AppColors.secondary,
                      children: [
                        _PriceField(
                          label: 'Giá mở cửa giao hàng',
                          controller: _basePriceDeliveryCtrl,
                          unit: 'đ',
                          hint: '18000',
                        ),
                        _PriceField(
                          label: 'Giá mỗi km giao hàng',
                          controller: _pricePerKmDeliveryCtrl,
                          unit: 'đ/km',
                          hint: '7000',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Chính sách Nền tảng
                    _PricingSection(
                      title: '⚙️ Chính sách Nền tảng',
                      color: AppColors.accent,
                      children: [
                        _PriceField(
                          label: 'Tỷ lệ hoa hồng chiết khấu',
                          controller: _commissionCtrl,
                          unit: '%',
                          hint: '15',
                          max: 100,
                        ),
                        _PriceField(
                          label: 'Bán kính quét tài xế tối đa',
                          controller: _maxRadiusCtrl,
                          unit: 'km',
                          hint: '5.0',
                          isDouble: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Thời gian chờ
                    _PricingSection(
                      title: '⏱ Cấu hình Timeout',
                      color: AppColors.warning,
                      children: [
                        _PriceField(
                          label: 'Thời gian tài xế quyết định nhận',
                          controller: _driverTimeoutCtrl,
                          unit: 'giây',
                          hint: '15',
                        ),
                        _PriceField(
                          label: 'Thời gian quét tìm tài xế (Radar)',
                          controller: _radarTimeoutCtrl,
                          unit: 'giây',
                          hint: '45',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: _isSaving ? null : _saveSettings,
                        icon: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5),
                              )
                            : const Icon(Icons.save_rounded),
                        label: Text(
                          _isSaving ? 'Đang lưu...' : 'Lưu cấu hình',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}

class _PricingSection extends StatelessWidget {
  final String title;
  final Color color;
  final List<Widget> children;

  const _PricingSection({
    required this.title,
    required this.color,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _PriceField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String unit;
  final String hint;
  final double? max;
  final bool isDouble;

  const _PriceField({
    required this.label,
    required this.controller,
    required this.unit,
    required this.hint,
    this.max,
    this.isDouble = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            keyboardType: isDouble
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.number,
            decoration: InputDecoration(
              hintText: hint,
              suffixText: unit,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Không được để trống';
              final num = double.tryParse(v);
              if (num == null || num < 0) return 'Giá trị không hợp lệ';
              if (max != null && num > max!) {
                return 'Tối đa $max';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}

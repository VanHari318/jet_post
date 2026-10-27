import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/app_dialogs.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/validators.dart';
import '../../../routes/app_routes.dart';
import '../services/user_service.dart';
import 'kyc_pending_screen.dart';

/// Màn hình Đăng ký Đối tác Tài xế eKYC (Driver eKYC Screen)
/// Thu thập thông tin phương tiện, chụp CCCD 2 mặt & Giấy phép lái xe qua Cloudinary
class DriverEkycScreen extends StatefulWidget {
  const DriverEkycScreen({super.key});

  @override
  State<DriverEkycScreen> createState() => _DriverEkycScreenState();
}

class _DriverEkycScreenState extends State<DriverEkycScreen> {
  int _currentStep = 0;
  final ImagePicker _picker = ImagePicker();

  // Dữ liệu Bước 1: Phương tiện
  String _selectedVehicleType = 'Xe máy Honda';
  final TextEditingController _plateController = TextEditingController();

  // Dữ liệu Bước 2: CCCD
  File? _idCardFrontFile;
  String? _idCardFrontUrl;
  bool _isUploadingFront = false;

  File? _idCardBackFile;
  String? _idCardBackUrl;
  bool _isUploadingBack = false;

  // Dữ liệu Bước 3: GPLX
  File? _licenseFile;
  String? _licenseUrl;
  bool _isUploadingLicense = false;

  bool _agreedToTerms = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _checkExistingKyc();
  }

  Future<void> _checkExistingKyc() async {
    final uid = FirebaseService.currentUserId;
    if (uid == null) return;
    final driver = await UserService.instance.getDriverProfile(uid);
    if (!mounted || driver == null) return;

    if (driver.status == DriverApprovalStatus.pendingApproval) {
      AppLogger.ekyc('Bảo vệ Route eKYC', 'Hồ sơ đang Chờ Duyệt, chuyển hướng sang KycPendingScreen');
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => KycPendingScreen(plateNumber: driver.plateNumber),
        ),
      );
    } else if (driver.status == DriverApprovalStatus.active) {
      AppLogger.ekyc('Bảo vệ Route eKYC', 'Tài xế đã Hoạt Động, chuyển hướng sang DriverDashboard');
      Navigator.pushReplacementNamed(context, AppRoutes.driverDashboard);
    }
  }

  @override
  void dispose() {
    _plateController.dispose();
    super.dispose();
  }

  // Chọn hoặc chụp ảnh
  Future<void> _pickAndUploadImage({
    required DriverKycDocType docType,
    required ImageSource source,
  }) async {
    try {
      AppLogger.userAction('DriverEKYC', 'Mở trình chọn ảnh', {
        'docType': docType.name,
        'source': source.name,
      });

      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
      );

      if (picked == null) {
        AppLogger.info('DriverEKYC', 'Người dùng đã hủy chọn ảnh');
        return;
      }
      if (!mounted) return;

      final formatErr = AppValidators.validateImageFile(filePath: picked.path);
      if (formatErr != null) {
        AppDialogs.showError(context, title: 'Định Dạng Không Hợp Lệ', message: formatErr);
        return;
      }

      final file = File(picked.path);
      final fileSize = await file.length();
      if (!mounted) return;
      if (fileSize > 10 * 1024 * 1024) {
        AppDialogs.showError(
          context,
          title: 'Dung Lượng Quá Lớn',
          message: 'Dung lượng ảnh vượt quá 10MB! Vui lòng chọn ảnh nhẹ hơn.',
        );
        return;
      }

      final driverId = UserService.instance.formatToE164(
        _plateController.text.isNotEmpty ? _plateController.text : 'driver_temp',
      );

      AppLogger.ekyc('Upload Ảnh', 'Bắt đầu upload Cloudinary', '${docType.name} - file: ${picked.name} (${(fileSize / 1024).toStringAsFixed(1)} KB)');

      setState(() {
        if (docType == DriverKycDocType.idCardFront) {
          _idCardFrontFile = file;
          _isUploadingFront = true;
        } else if (docType == DriverKycDocType.idCardBack) {
          _idCardBackFile = file;
          _isUploadingBack = true;
        } else {
          _licenseFile = file;
          _isUploadingLicense = true;
        }
      });

      // Upload lên Cloudinary vào thư mục jetpost/drivers_ekyc
      final secureUrl = await CloudinaryService.instance.uploadDriverKyc(
        imageFile: file,
        driverId: driverId,
        docType: docType,
      );

      if (!mounted) return;

      setState(() {
        if (docType == DriverKycDocType.idCardFront) {
          _idCardFrontUrl = secureUrl;
          _isUploadingFront = false;
        } else if (docType == DriverKycDocType.idCardBack) {
          _idCardBackUrl = secureUrl;
          _isUploadingBack = false;
        } else {
          _licenseUrl = secureUrl;
          _isUploadingLicense = false;
        }
      });

      if (secureUrl != null) {
        AppLogger.ekyc('Upload Ảnh', 'THÀNH CÔNG', '${docType.name} ➔ $secureUrl');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tải ảnh lên đám mây Cloudinary thành công!'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        AppLogger.error('DriverEKYC', 'Upload ảnh lên Cloudinary thất bại: ${docType.name}');
        AppDialogs.showError(
          context,
          title: 'Tải Ảnh Thất Bại',
          message: 'Không thể tải ảnh lên máy chủ Cloudinary. Vui lòng kiểm tra lại kết nối mạng và thử lại!',
        );
      }
    } catch (e) {
      AppLogger.error('DriverEKYC', 'Lỗi chọn ảnh', e);
    }
  }

  void _showImagePickerModal(DriverKycDocType docType) {
    AppLogger.userAction('DriverEKYC', 'Mở BottomSheet chọn nguồn ảnh', {'docType': docType.name});
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Chọn Nguồn Ảnh Giấy Tờ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                title: const Text('Chụp ảnh trực tiếp từ Camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadImage(docType: docType, source: ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.secondary),
                title: const Text('Chọn ảnh sẵn có từ Thư viện'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadImage(docType: docType, source: ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Nộp toàn bộ hồ sơ
  Future<void> _handleSubmitApplication() async {
    final plate = _plateController.text.trim();
    AppLogger.userAction('DriverEKYC', 'Bấm Gửi Hồ Sơ Thẩm Định', {
      'vehicleType': _selectedVehicleType,
      'plate': plate,
      'hasFront': _idCardFrontUrl != null,
      'hasBack': _idCardBackUrl != null,
      'hasLicense': _licenseUrl != null,
      'agreed': _agreedToTerms,
    });

    final vehicleErr = AppValidators.validateVehicleType(_selectedVehicleType);
    if (vehicleErr != null) {
      AppDialogs.showError(context, title: 'Chưa Chọn Loại Xe', message: vehicleErr);
      return;
    }

    final plateErr = AppValidators.validatePlateNumber(plate);
    if (plateErr != null) {
      AppDialogs.showError(context, title: 'Biển Số Không Hợp Lệ', message: plateErr);
      return;
    }
    if (_idCardFrontUrl == null) {
      AppDialogs.showError(context, title: 'Thiếu Ảnh CCCD', message: 'Vui lòng chụp và tải ảnh CCCD mặt trước rõ nét!');
      return;
    }
    if (_idCardBackUrl == null) {
      AppDialogs.showError(context, title: 'Thiếu Ảnh CCCD', message: 'Vui lòng chụp và tải ảnh CCCD mặt sau rõ nét!');
      return;
    }
    if (_licenseUrl == null) {
      AppDialogs.showError(context, title: 'Thiếu Ảnh Bằng Lái', message: 'Vui lòng chụp và tải ảnh Giấy phép lái xe!');
      return;
    }
    if (!_agreedToTerms) {
      AppDialogs.showError(context, title: 'Chưa Đồng Ý Cam Kết', message: 'Vui lòng đồng ý với cam kết xác thực hồ sơ trước pháp luật!');
      return;
    }

    // Chặn nộp lại nếu hồ sơ hiện tại đang trong trạng thái chờ duyệt
    final uid = FirebaseService.currentUserId;
    if (uid != null) {
      final existing = await UserService.instance.getDriverProfile(uid);
      if (!mounted) return;
      if (existing != null && existing.status == DriverApprovalStatus.pendingApproval) {
        AppDialogs.showError(
          context,
          title: 'Hồ Sơ Đang Chờ Duyệt',
          message: 'Bạn đã có một hồ sơ đăng ký tài xế đang trong trạng thái chờ Ban Quản trị phê duyệt!\n\nVui lòng không nộp lại hồ sơ.',
        );
        return;
      }
    }

    setState(() {
      _isSubmitting = true;
    });

    final success = await UserService.instance.submitDriverKyc(
      vehicleType: _selectedVehicleType,
      plateNumber: plate,
      idCardFrontUrl: _idCardFrontUrl!,
      idCardBackUrl: _idCardBackUrl!,
      licenseUrl: _licenseUrl!,
    );

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
    });

    if (success) {
      AppLogger.navigation('DriverEKYC', 'KycPendingScreen', {'plate': plate});
      await AppDialogs.showSuccess(
        context,
        title: 'Gửi Hồ Sơ Thành Công',
        message: 'Hồ sơ đăng ký đối tác tài xế của bạn đã được gửi thành công đến Ban Quản Trị (Admin) để thẩm định!',
        buttonText: 'Xem Trạng Thái',
        onConfirmed: () {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => KycPendingScreen(plateNumber: plate),
            ),
          );
        },
      );
    } else {
      AppDialogs.showError(
        context,
        title: 'Nộp Hồ Sơ Thất Bại',
        message: 'Có lỗi xảy ra khi nộp hồ sơ. Vui lòng thử lại!',
      );
    }
  }

  Future<void> _handleStepContinue() async {
    if (_currentStep == 0) {
      final plate = _plateController.text.trim();
      final plateErr = AppValidators.validatePlateNumber(plate);
      if (plateErr != null) {
        AppDialogs.showError(context, title: 'Biển Số Không Hợp Lệ', message: plateErr);
        return;
      }
      final vehicleErr = AppValidators.validateVehicleType(_selectedVehicleType);
      if (vehicleErr != null) {
        AppDialogs.showError(context, title: 'Chưa Chọn Loại Xe', message: vehicleErr);
        return;
      }

      // KIỂM TRA TIỀN TRẠM BIỂN SỐ XE (PRE-FLIGHT UNIQUENESS CHECK):
      final isTaken = await UserService.instance.isPlateAlreadyRegistered(
        plate,
        excludeDriverId: FirebaseService.currentUserId,
      );
      if (!mounted) return;
      if (isTaken) {
        AppDialogs.showError(
          context,
          title: 'Biển Số Xe Đã Tồn Tại',
          message: 'Biển kiểm soát xe $plate đã được đăng ký bởi một đối tác tài xế khác trong hệ thống JetPost. Vui lòng kiểm tra lại!',
        );
        return; // DỪNG LẬP TỨC: Không cho sang Bước 2!
      }

      setState(() => _currentStep = 1);
    } else if (_currentStep == 1) {
      if (_idCardFrontUrl == null) {
        AppDialogs.showError(context, title: 'Thiếu Ảnh CCCD', message: 'Vui lòng chụp và tải ảnh CCCD mặt trước rõ nét!');
        return;
      }
      if (_idCardBackUrl == null) {
        AppDialogs.showError(context, title: 'Thiếu Ảnh CCCD', message: 'Vui lòng chụp và tải ảnh CCCD mặt sau rõ nét!');
        return;
      }
      setState(() => _currentStep = 2);
    } else {
      _handleSubmitApplication();
    }
  }



  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đăng Ký Đối Tác Tài Xế (eKYC)'),
      ),
      body: SafeArea(
        child: Stepper(
          currentStep: _currentStep,
          type: StepperType.horizontal,
          onStepTapped: (step) => setState(() => _currentStep = step),
          onStepContinue: _handleStepContinue,
          onStepCancel: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            }
          },
          controlsBuilder: (context, details) {
            final isLastStep = _currentStep == 2;
            final bottomPadding = MediaQuery.of(context).padding.bottom;
            return Padding(
              padding: EdgeInsets.only(top: 24, bottom: bottomPadding + 16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : details.onStepContinue,
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : Text(isLastStep ? 'Gửi Hồ Sơ Thẩm Định' : 'Tiếp Tục'),
                    ),
                  ),
                  if (_currentStep > 0) ...[
                    const SizedBox(width: 12),
                    OutlinedButton(
                      onPressed: details.onStepCancel,
                      child: const Text('Quay Lại'),
                    ),
                  ],
                ],
              ),
            );
          },
          steps: [
            // BƯỚC 1: THÔNG TIN PHƯƠNG TIỆN
            Step(
              title: const Text('Phương tiện'),
              isActive: _currentStep >= 0,
              state: _currentStep > 0 ? StepState.complete : StepState.indexed,
              content: _buildStepVehicle(isDark),
            ),

            // BƯỚC 2: CCCD 2 MẶT
            Step(
              title: const Text('CCCD'),
              isActive: _currentStep >= 1,
              state: _currentStep > 1 ? StepState.complete : StepState.indexed,
              content: _buildStepCccd(isDark),
            ),

            // BƯỚC 3: GIẤY PHÉP LÁI XE
            Step(
              title: const Text('Bằng lái'),
              isActive: _currentStep >= 2,
              state: StepState.indexed,
              content: _buildStepLicense(isDark),
            ),
          ],
        ),
      ),
    );
  }

  // Giao diện Bước 1: Phương tiện
  Widget _buildStepVehicle(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '1. Thông Tin Xe Máy Chở Khách & Giao Hàng',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Cung cấp chính xác thông tin phương tiện xe gắn máy bạn sẽ sử dụng hoạt động.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 20),

        // Dropdown Hãng xe
        const Text('Loại xe máy', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _selectedVehicleType,
          isExpanded: true,
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
          items: const [
            DropdownMenuItem(
              value: 'Xe máy Honda',
              child: Text(
                'Xe máy Honda (Wave, Vision, AirBlade...)',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: 'Xe máy Yamaha',
              child: Text(
                'Xe máy Yamaha (Sirius, Exciter, Grande...)',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: 'Xe máy Điện VinFast',
              child: Text(
                'Xe máy Điện (VinFast, Dat Bike...)',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            DropdownMenuItem(
              value: 'Loại xe khác',
              child: Text(
                'Loại xe khác',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          onChanged: (val) {
            if (val != null) setState(() => _selectedVehicleType = val);
          },
        ),

        const SizedBox(height: 18),

        // Biển số xe
        const Text('Biển số xe máy', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _plateController,
          textCapitalization: TextCapitalization.characters,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: AppValidators.validatePlateNumber,
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
          decoration: InputDecoration(
            hintText: 'Ví dụ: 29-E1 123.45 hoặc 59-X3 678.90',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.pin, color: AppColors.primary),
          ),
        ),
      ],
    );
  }

  // Giao diện Bước 2: CCCD
  Widget _buildStepCccd(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '2. Chụp Ảnh Căn Cước Công Dân (CCCD 2 Mặt)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Chụp rõ nét, không bị lóa sáng, hiển thị đầy đủ 4 góc của thẻ CCCD.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 20),

        // Khung chụp Mặt trước
        _buildUploadBox(
          title: 'Mặt trước Căn cước công dân',
          file: _idCardFrontFile,
          url: _idCardFrontUrl,
          isUploading: _isUploadingFront,
          onTap: () => _showImagePickerModal(DriverKycDocType.idCardFront),
          isDark: isDark,
        ),

        const SizedBox(height: 16),

        // Khung chụp Mặt sau
        _buildUploadBox(
          title: 'Mặt sau Căn cước công dân',
          file: _idCardBackFile,
          url: _idCardBackUrl,
          isUploading: _isUploadingBack,
          onTap: () => _showImagePickerModal(DriverKycDocType.idCardBack),
          isDark: isDark,
        ),
      ],
    );
  }

  // Giao diện Bước 3: Giấy phép lái xe
  Widget _buildStepLicense(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '3. Chụp Giấy Phép Lái Xe (Bằng Lái A1/A2)',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Bằng lái xe máy hợp pháp còn thời hạn theo quy định Bộ GTVT.',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 20),

        _buildUploadBox(
          title: 'Ảnh chụp Giấy phép lái xe',
          file: _licenseFile,
          url: _licenseUrl,
          isUploading: _isUploadingLicense,
          onTap: () => _showImagePickerModal(DriverKycDocType.license),
          isDark: isDark,
        ),

        const SizedBox(height: 20),

        // Cam kết
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ),
          child: Row(
            children: [
              Checkbox(
                value: _agreedToTerms,
                activeColor: AppColors.primary,
                onChanged: (val) => setState(() => _agreedToTerms = val ?? false),
              ),
              Expanded(
                child: Text(
                  'Tôi cam kết các thông tin cá nhân và hình ảnh giấy tờ tùy thân cung cấp là hoàn toàn chính xác và chịu trách nhiệm trước pháp luật.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Khung Upload ảnh tài liệu
  Widget _buildUploadBox({
    required String title,
    required File? file,
    required String? url,
    required bool isUploading,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final hasImage = file != null;

    return InkWell(
      onTap: isUploading ? null : onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 150,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : const Color(0xFFF8F9FA),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: url != null
                ? AppColors.success
                : (isDark ? AppColors.borderDark : AppColors.borderLight),
            width: url != null ? 1.8 : 1.2,
          ),
        ),
        child: isUploading
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(strokeWidth: 2.5),
                    SizedBox(height: 10),
                    Text('Đang nạp ảnh lên Cloudinary...', style: TextStyle(fontSize: 12)),
                  ],
                ),
              )
            : hasImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(file, fit: BoxFit.cover),
                        Container(
                          color: Colors.black.withAlpha(50),
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                              color: Colors.black.withAlpha(150),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.check_circle, color: AppColors.success, size: 16),
                                      const SizedBox(width: 6),
                                      Text(
                                        title,
                                        style: const TextStyle(color: Colors.white, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  const Text('Chạm để đổi', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        size: 36,
                        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Chạm để chụp hoặc chọn ảnh từ máy',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}

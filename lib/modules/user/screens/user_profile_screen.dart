import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/app_dialogs.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/validators.dart';
import '../../../models/user_model.dart';
import '../../../routes/app_routes.dart';
import '../services/user_service.dart';
import '../widgets/role_badge.dart';
import 'kyc_pending_screen.dart';

/// Màn hình Quản lý Hồ sơ Cá nhân & Bảo mật Tài khoản (User Profile Screen)
/// Quản lý:
/// 1. Cập nhật Họ và Tên (Validation)
/// 2. Cập nhật Ảnh đại diện qua Cloudinary CDN (Folder jetpost/avatars)
/// 3. Hiển thị & Điều hướng sang Màn hình Liên kết Email/Mật khẩu riêng biệt
/// 4. Đổi Số Điện Thoại An Toàn qua Màn hình ChangePhoneScreen riêng biệt
/// 5. Banner chuyển tiếp trực tiếp sang Đăng ký eKYC Tài Xế
/// 6. Tối ưu Window Insets, không bao giờ bị đè dưới nút Home của Android
class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  UserModel? _currentUser;
  bool _isLoading = true;
  bool _isSavingName = false;
  bool _isUploadingAvatar = false;

  final TextEditingController _nameController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  String? _nameError;

  @override
  void initState() {
    super.initState();
    AppLogger.navigation('Profile', 'UserProfileScreen', {});
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // Tải thông tin hồ sơ người dùng
  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    final user = await UserService.instance.getCurrentUserProfile();
    if (!mounted) return;

    setState(() {
      _currentUser = user;
      _isLoading = false;
      if (user != null) {
        _nameController.text = user.fullName;
      }
    });
  }

  // Cập nhật họ tên với validation chặt chẽ
  Future<void> _handleSaveName() async {
    final newName = _nameController.text.trim();
    AppLogger.userAction('Profile', 'Bấm Lưu họ tên', {'newName': newName});

    final valErr = AppValidators.validateFullName(newName);
    if (valErr != null) {
      setState(() => _nameError = valErr);
      AppDialogs.showError(context, title: 'Họ Tên Không Hợp Lệ', message: valErr);
      return;
    }

    setState(() {
      _nameError = null;
      _isSavingName = true;
    });

    final success = await UserService.instance.updateUserProfile(fullName: newName);

    if (!mounted) return;
    setState(() => _isSavingName = false);

    if (success) {
      AppLogger.info('Profile', 'Cập nhật họ tên thành công: $newName');
      AppDialogs.showSuccess(
        context,
        title: 'Cập Nhật Thành Công',
        message: 'Họ và tên của bạn đã được cập nhật thành công thành "$newName"!',
      );
      _loadProfile();
    } else {
      AppLogger.error('Profile', 'Cập nhật họ tên thất bại');
      AppDialogs.showError(
        context,
        title: 'Cập Nhật Thất Bại',
        message: 'Không thể cập nhật họ tên lúc này. Vui lòng kiểm tra lại kết nối mạng!',
      );
    }
  }

  // Chọn ảnh đại diện và tải lên Cloudinary
  Future<void> _pickAndUploadAvatar(ImageSource source) async {
    if (_currentUser == null) return;
    AppLogger.userAction('Profile', 'Bắt đầu chọn ảnh Avatar', {'source': source.name});

    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 85,
      );

      if (picked == null) {
        AppLogger.info('Profile', 'Hủy chọn ảnh đại diện');
        return;
      }

      final formatErr = AppValidators.validateImageFile(filePath: picked.path);
      if (formatErr != null) {
        if (!mounted) return;
        AppDialogs.showError(context, title: 'Định Dạng Ảnh Không Hợp Lệ', message: formatErr);
        return;
      }

      final file = File(picked.path);
      if (await file.length() > 10 * 1024 * 1024) {
        if (!mounted) return;
        AppDialogs.showError(
          context,
          title: 'Dung Lượng Ảnh Quá Lớn',
          message: 'Dung lượng ảnh vượt quá 10MB! Vui lòng chọn ảnh nhẹ hơn.',
        );
        return;
      }

      setState(() => _isUploadingAvatar = true);
      AppLogger.info('Profile', 'Đang tải Avatar lên Cloudinary (jetpost/avatars)...');

      final secureUrl = await CloudinaryService.instance.uploadAvatar(
        imageFile: file,
        userId: _currentUser!.id,
      );

      if (secureUrl != null) {
        AppLogger.info('Profile', 'Upload Avatar Cloudinary thành công: $secureUrl');
        await UserService.instance.updateUserProfile(avatarUrl: secureUrl);
        await _loadProfile();
        if (mounted) {
          AppDialogs.showSuccess(
            context,
            title: 'Đổi Ảnh Đại Diện Thành Công',
            message: 'Ảnh đại diện của bạn đã được cập nhật thành công lên đám mây Cloudinary!',
          );
        }
      } else {
        AppLogger.error('Profile', 'Tải Avatar lên Cloudinary thất bại');
        if (mounted) {
          AppDialogs.showError(
            context,
            title: 'Tải Ảnh Thất Bại',
            message: 'Không thể tải ảnh lên máy chủ Cloudinary. Vui lòng thử lại sau!',
          );
        }
      }
    } catch (e) {
      AppLogger.error('Profile', 'Lỗi đổi avatar', e);
      if (mounted) {
        AppDialogs.showError(context, title: 'Lỗi Tải Ảnh', message: '$e');
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingAvatar = false);
      }
    }
  }

  void _showAvatarPickerModal() {
    AppLogger.userAction('Profile', 'Mở modal chọn nguồn ảnh đại diện');
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
                'Cập Nhật Ảnh Đại Diện',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 14),
              ListTile(
                leading: const Icon(Icons.camera_alt, color: AppColors.primary),
                title: const Text('Chụp ảnh mới từ Camera'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadAvatar(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: AppColors.secondary),
                title: const Text('Chọn ảnh từ Thư viện'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadAvatar(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Mở Màn hình Đổi số điện thoại riêng biệt
  Future<void> _openChangePhoneScreen() async {
    if (_currentUser == null) return;
    AppLogger.userAction('Profile', 'Mở màn hình Đổi số điện thoại');
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.changePhone,
      arguments: {
        'currentPhone': _currentUser!.phone,
        'linkedEmail': _currentUser!.email,
      },
    );

    if (result == true) {
      _loadProfile();
    }
  }

  // Mở Màn hình Liên kết Email & Mật khẩu riêng biệt
  Future<void> _openLinkEmailScreen() async {
    if (_currentUser == null) return;
    AppLogger.userAction('Profile', 'Mở màn hình Liên kết Email');
    final result = await Navigator.pushNamed(
      context,
      AppRoutes.linkEmail,
    );

    if (result == true) {
      _loadProfile();
    }
  }

  // Mở Popup Đổi Mật Khẩu An Toàn
  void _showChangePasswordDialog() {
    AppLogger.userAction('Profile', 'Mở popup Đổi Mật Khẩu');
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool isCurrentVisible = false;
    bool isNewVisible = false;
    bool isConfirmVisible = false;
    bool isSubmitting = false;
    String? currentError;
    String? newError;
    String? confirmError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (context, setDlgState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
            contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: const Row(
              children: [
                Icon(Icons.lock_reset, color: AppColors.primary),
                SizedBox(width: 8),
                Text('Đổi Mật Khẩu Tài Khoản', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Nhập mật khẩu hiện tại để xác minh danh tính và thiết lập mật khẩu mới:'),
                  const SizedBox(height: 16),

                  // Mật khẩu hiện tại
                  TextField(
                    controller: currentPassCtrl,
                    obscureText: !isCurrentVisible,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu hiện tại',
                      prefixIcon: const Icon(Icons.lock_outline),
                      errorText: currentError,
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: IconButton(
                        icon: Icon(isCurrentVisible ? Icons.visibility_off : Icons.visibility, size: 20),
                        onPressed: () => setDlgState(() => isCurrentVisible = !isCurrentVisible),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Mật khẩu mới
                  TextField(
                    controller: newPassCtrl,
                    obscureText: !isNewVisible,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu mới (tối thiểu 6 ký tự)',
                      prefixIcon: const Icon(Icons.lock_clock_outlined),
                      errorText: newError,
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: IconButton(
                        icon: Icon(isNewVisible ? Icons.visibility_off : Icons.visibility, size: 20),
                        onPressed: () => setDlgState(() => isNewVisible = !isNewVisible),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Xác nhận mật khẩu mới
                  TextField(
                    controller: confirmPassCtrl,
                    obscureText: !isConfirmVisible,
                    decoration: InputDecoration(
                      labelText: 'Xác nhận lại mật khẩu mới',
                      prefixIcon: const Icon(Icons.check_circle_outline),
                      errorText: confirmError,
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      suffixIcon: IconButton(
                        icon: Icon(isConfirmVisible ? Icons.visibility_off : Icons.visibility, size: 20),
                        onPressed: () => setDlgState(() => isConfirmVisible = !isConfirmVisible),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dlgCtx),
                child: const Text('Hủy'),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        final currentPass = currentPassCtrl.text;
                        final newPass = newPassCtrl.text;
                        final confirmPass = confirmPassCtrl.text;

                        setDlgState(() {
                          currentError = currentPass.isEmpty ? 'Vui lòng nhập mật khẩu hiện tại' : null;
                          newError = AppValidators.validatePassword(newPass);
                          confirmError = AppValidators.validateConfirmPassword(confirmPass, newPass);
                        });

                        if (currentError != null || newError != null || confirmError != null) return;

                        if (currentPass == newPass) {
                          setDlgState(() {
                            newError = 'Mật khẩu mới không được trùng mật khẩu cũ!';
                          });
                          return;
                        }

                        setDlgState(() => isSubmitting = true);

                        try {
                          await UserService.instance.changePassword(
                            currentPassword: currentPass,
                            newPassword: newPass,
                          );
                          if (!mounted) return;
                          if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                          AppDialogs.showSuccess(
                            this.context,
                            title: 'Đổi Mật Khẩu Thành Công',
                            message: 'Mật khẩu tài khoản của bạn đã được cập nhật thành công. Vui lòng ghi nhớ mật khẩu mới!',
                          );
                        } catch (e) {
                          setDlgState(() => isSubmitting = false);
                          if (!mounted) return;
                          AppDialogs.showError(
                            this.context,
                            title: 'Đổi Mật Khẩu Thất Bại',
                            message: e.toString().replaceAll('Exception: ', ''),
                          );
                        }
                      },
                child: isSubmitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Cập Nhật'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Đăng xuất
  Future<void> _handleLogout() async {
    AppLogger.userAction('Profile', 'Bấm nút Đăng xuất');
    final confirm = await AppDialogs.showConfirm(
      context,
      title: 'Đăng Xuất Tài Khoản',
      message: 'Bạn có chắc chắn muốn đăng xuất khỏi phiên làm việc hiện tại không?',
      confirmText: 'Đăng xuất',
      confirmColor: AppColors.error,
    );

    if (confirm) {
      AppLogger.auth('Xác nhận đăng xuất, điều hướng về WelcomeGate');
      await UserService.instance.clearUserSession();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.welcomeGate,
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ Sơ Cá Nhân'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Cài đặt',
            onPressed: () => Navigator.pushNamed(context, AppRoutes.appSettings),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentUser == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Chưa có thông tin đăng nhập!'),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () => Navigator.pushNamed(context, AppRoutes.phoneAuth),
                        child: const Text('Đăng nhập ngay'),
                      ),
                    ],
                  ),
                )
              : SafeArea(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: 24,
                      right: 24,
                      top: 20,
                      bottom: bottomPadding + 28,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Cụm Avatar tròn với nút đổi ảnh
                        Center(
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 54,
                                backgroundColor: AppColors.primary.withAlpha(30),
                                backgroundImage: _currentUser!.avatarUrl != null &&
                                        _currentUser!.avatarUrl!.isNotEmpty
                                    ? NetworkImage(
                                        CloudinaryService.instance.getOptimizedUrl(
                                          _currentUser!.avatarUrl!,
                                          width: 250,
                                          height: 250,
                                        ),
                                      )
                                    : null,
                                child: _isUploadingAvatar
                                    ? const CircularProgressIndicator(color: AppColors.primary)
                                    : (_currentUser!.avatarUrl == null ||
                                            _currentUser!.avatarUrl!.isEmpty)
                                        ? Text(
                                            _currentUser!.fullName.isNotEmpty
                                                ? _currentUser!.fullName[0].toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              fontSize: 36,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.primary,
                                            ),
                                          )
                                        : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: InkWell(
                                  onTap: _isUploadingAvatar ? null : _showAvatarPickerModal,
                                  borderRadius: BorderRadius.circular(20),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark ? AppColors.surfaceDark : Colors.white,
                                        width: 2.5,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Vai trò tài khoản (Role Badge)
                        Center(
                          child: RoleBadge(role: _currentUser!.role),
                        ),

                        const SizedBox(height: 28),

                        // Trường Họ và Tên
                        const Text(
                          'Họ và Tên',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _nameController,
                                decoration: InputDecoration(
                                  hintText: 'Nhập họ và tên đầy đủ',
                                  prefixIcon: const Icon(Icons.person_outline),
                                  errorText: _nameError,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  isDense: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            SizedBox(
                              height: 48,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                ),
                                onPressed: _isSavingName ? null : _handleSaveName,
                                child: _isSavingName
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Lưu'),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Trường Số Điện thoại (Có nút Đổi số điện thoại xác thực OTP)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Số điện thoại xác thực',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                            ),
                            TextButton.icon(
                              onPressed: _openChangePhoneScreen,
                              icon: const Icon(Icons.edit_outlined, size: 14, color: AppColors.primary),
                              label: Text(
                                _currentUser!.phone.isNotEmpty ? 'Đổi số khác' : 'Liên kết SĐT',
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceDark : const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? AppColors.borderDark : AppColors.borderLight,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.phone, color: AppColors.primary, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _currentUser!.phone.isNotEmpty
                                      ? _currentUser!.phone
                                      : 'Chưa liên kết số điện thoại',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: _currentUser!.phone.isNotEmpty ? FontWeight.bold : FontWeight.normal,
                                    color: _currentUser!.phone.isNotEmpty
                                        ? (isDark ? Colors.white : Colors.black87)
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                              if (_currentUser!.phone.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withAlpha(25),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.verified, size: 13, color: AppColors.success),
                                      SizedBox(width: 4),
                                      Text(
                                        'Đã xác minh',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Trường Email Liên kết
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Email liên kết & Mật khẩu',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                            ),
                            if (_currentUser!.email == null || _currentUser!.email!.isEmpty)
                              TextButton.icon(
                                onPressed: _openLinkEmailScreen,
                                icon: const Icon(Icons.link, size: 14, color: AppColors.primary),
                                label: const Text(
                                  'Liên kết ngay',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              )
                            else
                              TextButton.icon(
                                onPressed: _showChangePasswordDialog,
                                icon: const Icon(Icons.lock_reset, size: 14, color: AppColors.primary),
                                label: const Text(
                                  'Đổi mật khẩu',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  minimumSize: Size.zero,
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceDark : const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? AppColors.borderDark : AppColors.borderLight,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.email_outlined, color: AppColors.primary, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _currentUser!.email != null && _currentUser!.email!.isNotEmpty
                                      ? _currentUser!.email!
                                      : 'Chưa liên kết email',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: _currentUser!.email != null && _currentUser!.email!.isNotEmpty
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: _currentUser!.email != null && _currentUser!.email!.isNotEmpty
                                        ? (isDark ? Colors.white : Colors.black87)
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                              if (_currentUser!.email != null && _currentUser!.email!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.success.withAlpha(25),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.verified, size: 13, color: AppColors.success),
                                      SizedBox(width: 4),
                                      Text(
                                        'Đã xác minh',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Ngày tạo tài khoản
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.surfaceDark : const Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark ? AppColors.borderDark : AppColors.borderLight,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 18,
                                color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Ngày tham gia: ${DateFormat('dd/MM/yyyy HH:mm').format(_currentUser!.createdAt)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // BANNER ĐĂNG KÝ eKYC TÀI XẾ (NẾU ĐANG LÀ KHÁCH HÀNG)
                        if (_currentUser!.role != UserRole.driver) ...[
                          const SizedBox(height: 24),
                          _buildDriverEkycBanner(isDark),
                        ],

                        const SizedBox(height: 36),

                        // Nút Đăng xuất
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _handleLogout,
                          icon: const Icon(Icons.logout),
                          label: const Text('Đăng Xuất Tài Khoản', style: TextStyle(fontSize: 15)),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Future<void> _handleTapDriverEkycBanner() async {
    AppLogger.userAction('Profile', 'Chạm banner Đăng ký eKYC');
    final uid = FirebaseService.currentUserId;
    if (uid != null) {
      final driver = await UserService.instance.getDriverProfile(uid);
      if (!mounted) return;
      if (driver != null) {
        if (driver.status == DriverApprovalStatus.pendingApproval) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => KycPendingScreen(plateNumber: driver.plateNumber),
            ),
          );
          return;
        } else if (driver.status == DriverApprovalStatus.active) {
          Navigator.pushNamed(context, AppRoutes.driverDashboard);
          return;
        }
      }
    }
    if (!mounted) return;
    Navigator.pushNamed(context, AppRoutes.driverKyc);
  }

  Widget _buildDriverEkycBanner(bool isDark) {
    return InkWell(
      onTap: _handleTapDriverEkycBanner,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : const Color(0xFFFFF8E1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFB300), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFB300).withAlpha(40),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.badge_outlined, color: Color(0xFFE65100), size: 28),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Đăng Ký Gia Nhập Đối Tác Tài Xế (eKYC)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Chụp ảnh CCCD 2 mặt & Bằng lái xe để bắt đầu nhận cuốc',
                    style: TextStyle(fontSize: 12, color: Color(0xFFE65100), height: 1.3),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFFE65100)),
          ],
        ),
      ),
    );
  }
}

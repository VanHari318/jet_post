import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_dialogs.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/validators.dart';
import '../services/user_service.dart';
import '../widgets/otp_pin_input.dart';
import '../widgets/phone_input_field.dart';

/// Màn hình Riêng Biệt: Đổi Số Điện Thoại An Toàn (Change Phone Dedicated Screen)
/// Áp dụng cơ chế Step-up Verification (Xác minh danh tính chủ tài khoản -> Nhập SĐT mới -> Kích hoạt OTP)
/// Tích hợp Pre-flight Uniqueness Check (Chặn ngay nếu SĐT mới đã tồn tại)
/// Tối ưu 100% Window Insets, không bao giờ bị đè dưới nút Home của Android
class ChangePhoneScreen extends StatefulWidget {
  final String currentPhone;
  final String? linkedEmail;

  const ChangePhoneScreen({
    super.key,
    required this.currentPhone,
    this.linkedEmail,
  });

  @override
  State<ChangePhoneScreen> createState() => _ChangePhoneScreenState();
}

class _ChangePhoneScreenState extends State<ChangePhoneScreen> {
  final TextEditingController _newPhoneController = TextEditingController();
  final TextEditingController _step1OtpController = TextEditingController();

  // Phase:
  // 0: Chọn phương thức xác minh bước 1 (Email hoặc SĐT cũ)
  // 1: Nhập OTP xác thực bước 1
  // 2: Nhập SĐT mới
  // 3: Nhập OTP gửi về SĐT mới
  int _phase = 0;
  bool _isLoading = false;
  String _step1EmailHash = '';
  int _step1EmailExpires = 0;

  // Cooldown
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    AppLogger.navigation('ChangePhone', 'ChangePhoneScreen', {
      'hasEmail': widget.linkedEmail != null,
      'phone': widget.currentPhone,
    });
  }

  @override
  void dispose() {
    _newPhoneController.dispose();
    _step1OtpController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown([int seconds = 60]) {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds <= 1) {
        timer.cancel();
        if (mounted) setState(() => _cooldownSeconds = 0);
      } else {
        if (mounted) setState(() => _cooldownSeconds--);
      }
    });
  }

  // Gửi OTP bước 1
  Future<void> _handleSendStep1Otp() async {
    final email = widget.linkedEmail;
    if (email == null || email.isEmpty) {
      AppDialogs.showError(
        context,
        title: 'Cần liên kết Email',
        message:
            'Hãy liên kết email với tài khoản trước khi thêm hoặc đổi số điện thoại.',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await UserService.instance.sendEmailOtp(
        email: email,
        type: 'CHANGE_PHONE',
      );
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res['success'] == true) {
        _step1EmailHash = res['codeHash'] as String;
        _step1EmailExpires = res['expiresAt'] as int;
        _step1OtpController.clear();
        setState(() => _phase = 1);
        _startCooldown(60);
      } else {
        AppDialogs.showError(
          context,
          title: 'Gửi Mã Thất Bại',
          message:
              res['error'] as String? ?? 'Không thể gửi mã xác nhận đến Email.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppDialogs.showError(context, title: 'Lỗi Kết Nối', message: '$e');
    }
  }

  // Xác thực OTP bước 1
  void _handleVerifyStep1Otp(String code) {
    final otpErr = AppValidators.validateOtp(code);
    if (otpErr != null) {
      AppDialogs.showError(
        context,
        title: 'Mã OTP Không Hợp Lệ',
        message: otpErr,
      );
      return;
    }

    final email = widget.linkedEmail;
    if (email == null || email.isEmpty) return;
    final isMatched = UserService.instance.verifyEmailOtp(
      email: email,
      inputCode: code,
      expectedHash: _step1EmailHash,
      expiresAt: _step1EmailExpires,
    );

    if (isMatched) {
      setState(() => _phase = 2);
    } else {
      AppDialogs.showError(
        context,
        title: 'Xác Thực Thất Bại',
        message:
            'Mã xác nhận Email không chính xác hoặc đã quá thời hạn 5 phút. Vui lòng kiểm tra lại!',
      );
    }
  }

  // Cập nhật số điện thoại sau khi email đã được xác minh.
  Future<void> _handleSendStep2Otp() async {
    final rawPhone = _newPhoneController.text.trim();
    final phoneErr = AppValidators.validatePhone(rawPhone);
    if (phoneErr != null) {
      AppDialogs.showError(
        context,
        title: 'Số Điện Thoại Không Hợp Lệ',
        message: phoneErr,
      );
      return;
    }

    final formattedPhone = UserService.instance.formatToE164(rawPhone);
    final oldFormattedPhone = UserService.instance.formatToE164(
      widget.currentPhone,
    );

    if (formattedPhone == oldFormattedPhone) {
      AppDialogs.showError(
        context,
        title: 'Số Điện Thoại Trùng Nhau',
        message:
            'Số điện thoại mới phải khác với số điện thoại hiện tại của bạn!',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final isTaken = await UserService.instance.isPhoneAlreadyRegistered(
        formattedPhone,
      );
      if (isTaken) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        AppDialogs.showError(
          context,
          title: 'Số Điện Thoại Đã Tồn Tại',
          message:
              'Số điện thoại $rawPhone đã được đăng ký cho một tài khoản khác. Vui lòng sử dụng số khác.',
        );
        return;
      }

      final success = await UserService.instance.updateUserPhone(rawPhone);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (!success) {
        AppDialogs.showError(
          context,
          title: 'Cập Nhật Thất Bại',
          message: 'Không thể cập nhật số điện thoại. Vui lòng thử lại.',
        );
        return;
      }

      await AppDialogs.showSuccess(
        context,
        title: 'Cập Nhật Thành Công',
        message: 'Số điện thoại đã được thêm/cập nhật thành $rawPhone.',
        buttonText: 'Hoàn tất',
        onConfirmed: () => Navigator.pop(context, true),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppDialogs.showError(context, title: 'Cập Nhật Thất Bại', message: '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Đổi Số Điện Thoại An Toàn'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Thanh tiến trình các bước
            _buildStepIndicator(isDark),

            // Nội dung theo phase
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                child: _buildPhaseContent(isDark),
              ),
            ),

            // Footer hành động an toàn, có đệm khoảng cách nút Home Android
            Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: bottomPadding + 14,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? AppColors.borderDark
                        : AppColors.borderLight,
                  ),
                ),
              ),
              child: _buildFooterAction(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepIndicator(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : const Color(0xFFF8F9FA),
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildStepCircle(
            stepNum: 1,
            label: 'Xác minh chủ sở hữu',
            isActive: _phase == 0 || _phase == 1,
            isCompleted: _phase > 1,
            isDark: isDark,
          ),
          Expanded(
            child: Container(
              height: 2,
              color: _phase > 1
                  ? AppColors.primary
                  : (isDark ? AppColors.borderDark : Colors.grey[300]),
            ),
          ),
          _buildStepCircle(
            stepNum: 2,
            label: 'Nhập số điện thoại mới',
            isActive: _phase == 2,
            isCompleted: false,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildStepCircle({
    required int stepNum,
    required String label,
    required bool isActive,
    required bool isCompleted,
    required bool isDark,
  }) {
    final color = isCompleted
        ? AppColors.success
        : (isActive
              ? AppColors.primary
              : (isDark ? Colors.grey[700]! : Colors.grey[400]!));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: color,
          child: isCompleted
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : Text(
                  '$stepNum',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isActive || isCompleted
                ? FontWeight.bold
                : FontWeight.normal,
            color: isActive || isCompleted
                ? (isDark ? Colors.white : Colors.black87)
                : (isDark ? Colors.grey[500] : Colors.grey[600]),
          ),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildPhaseContent(bool isDark) {
    if (_phase == 0) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bước 1: Xác minh qua Email',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Mã OTP sẽ được gửi đến email liên kết để xác nhận bạn là chủ sở hữu tài khoản.',
            style: TextStyle(
              fontSize: 13.5,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),

          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.email_outlined, color: AppColors.primary),
            title: Text(widget.linkedEmail ?? 'Chưa liên kết email'),
            subtitle: const Text('Nhận mã xác minh qua email'),
          ),
        ],
      );
    } else if (_phase == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nhập Mã OTP Xác Minh Danh Tính',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'JetPost đã gửi mã OTP gồm 6 chữ số đến địa chỉ Email:\n${widget.linkedEmail}',
            style: TextStyle(
              fontSize: 13.5,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),

          OtpPinInput(
            controller: _step1OtpController,
            onCompleted: _handleVerifyStep1Otp,
          ),
          const SizedBox(height: 20),

          Center(
            child: _cooldownSeconds > 0
                ? Text(
                    'Gửi lại mã sau ${_cooldownSeconds}s',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textMutedDark
                          : AppColors.textMutedLight,
                    ),
                  )
                : TextButton.icon(
                    onPressed: _handleSendStep1Otp,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Gửi lại mã OTP'),
                  ),
          ),
        ],
      );
    } else if (_phase == 2) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Bước 2: Nhập Số Điện Thoại Mới',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Sau khi xác minh email, số điện thoại mới sẽ được lưu sau khi kiểm tra chưa được tài khoản khác sử dụng.',
            style: TextStyle(
              fontSize: 13.5,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),

          PhoneInputField(
            controller: _newPhoneController,
            onSubmitted: _handleSendStep2Otp,
          ),
        ],
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  Widget _buildFooterAction(bool isDark) {
    if (_phase == 0) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _isLoading ? null : _handleSendStep1Otp,
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Tiếp Tục Nhận Mã Xác Minh',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
        ),
      );
    } else if (_phase == 1) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _isLoading
              ? null
              : () => _handleVerifyStep1Otp(_step1OtpController.text),
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Xác Thực Bước 1',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
        ),
      );
    } else if (_phase == 2) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _isLoading ? null : _handleSendStep2Otp,
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Thêm số điện thoại',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
        ),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          onPressed: _isLoading ? null : _handleSendStep2Otp,
          child: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Thêm số điện thoại',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
        ),
      );
    }
  }
}

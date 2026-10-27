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
  final TextEditingController _step2OtpController = TextEditingController();

  // Phase:
  // 0: Chọn phương thức xác minh bước 1 (Email hoặc SĐT cũ)
  // 1: Nhập OTP xác thực bước 1
  // 2: Nhập SĐT mới
  // 3: Nhập OTP gửi về SĐT mới
  int _phase = 0;
  bool _isLoading = false;
  String _step1Method = 'email'; // 'email' | 'phone'

  // Verification states
  String _step1EmailHash = '';
  int _step1EmailExpires = 0;
  String _step1PhoneVerificationId = '';
  String _step2PhoneVerificationId = '';

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

    if (widget.linkedEmail != null && widget.linkedEmail!.isNotEmpty) {
      _step1Method = 'email';
    } else {
      _step1Method = 'phone';
    }
  }

  @override
  void dispose() {
    _newPhoneController.dispose();
    _step1OtpController.dispose();
    _step2OtpController.dispose();
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
    setState(() => _isLoading = true);

    if (_step1Method == 'email' && widget.linkedEmail != null) {
      try {
        final res = await UserService.instance.sendEmailOtp(
          email: widget.linkedEmail!,
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
            message: res['error'] as String? ?? 'Không thể gửi mã xác nhận đến Email.',
          );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        AppDialogs.showError(context, title: 'Lỗi Kết Nối', message: '$e');
      }
    } else {
      // Gửi OTP về SĐT cũ
      try {
        await UserService.instance.sendOtpCode(
          phoneNumber: widget.currentPhone,
          onCodeSent: (verificationId, resendToken) {
            if (!mounted) return;
            setState(() {
              _step1PhoneVerificationId = verificationId;
              _isLoading = false;
              _phase = 1;
            });
            _step1OtpController.clear();
            _startCooldown(60);
          },
          onError: (errMsg) {
            if (!mounted) return;
            setState(() => _isLoading = false);
            AppDialogs.showError(context, title: 'Lỗi Gửi Mã SMS', message: errMsg);
          },
          onAutoVerified: (_) {},
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        AppDialogs.showError(context, title: 'Lỗi Viễn Thông', message: '$e');
      }
    }
  }

  // Xác thực OTP bước 1
  void _handleVerifyStep1Otp(String code) {
    final otpErr = AppValidators.validateOtp(code);
    if (otpErr != null) {
      AppDialogs.showError(context, title: 'Mã OTP Không Hợp Lệ', message: otpErr);
      return;
    }

    if (_step1Method == 'email') {
      final isMatched = UserService.instance.verifyEmailOtp(
        email: widget.linkedEmail!,
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
          message: 'Mã xác nhận Email không chính xác hoặc đã quá thời hạn 5 phút. Vui lòng kiểm tra lại!',
        );
      }
    } else {
      // SĐT cũ
      if (_step1PhoneVerificationId.isEmpty) {
        AppDialogs.showError(
          context,
          title: 'Chưa Gửi Mã SMS',
          message: 'Vui lòng nhấn nút gửi mã xác thực về số điện thoại trước khi xác minh.',
        );
        return;
      }
      setState(() => _phase = 2);
    }
  }

  // Gửi OTP tới SĐT Mới (TÍCH HỢP PRE-FLIGHT UNIQUENESS CHECK)
  Future<void> _handleSendStep2Otp() async {
    final rawPhone = _newPhoneController.text.trim();
    final phoneErr = AppValidators.validatePhone(rawPhone);
    if (phoneErr != null) {
      AppDialogs.showError(context, title: 'Số Điện Thoại Không Hợp Lệ', message: phoneErr);
      return;
    }

    final formattedPhone = UserService.instance.formatToE164(rawPhone);
    final oldFormattedPhone = UserService.instance.formatToE164(widget.currentPhone);

    if (formattedPhone == oldFormattedPhone) {
      AppDialogs.showError(
        context,
        title: 'Số Điện Thoại Trùng Nhau',
        message: 'Số điện thoại mới phải khác với số điện thoại hiện tại của bạn!',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. KIỂM TRA TIỀN TRẠM (PRE-FLIGHT UNIQUENESS CHECK):
      final isTaken = await UserService.instance.isPhoneAlreadyRegistered(formattedPhone);
      if (isTaken) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        AppDialogs.showError(
          context,
          title: 'Số Điện Thoại Đã Tồn Tại',
          message: 'Số điện thoại $rawPhone đã được đăng ký cho một tài khoản khác trong hệ thống JetPost. Vui lòng sử dụng số điện thoại khác!',
        );
        return; // DỪNG LẬP TỨC: Không gửi OTP, không chuyển bước!
      }

      // 2. NẾU HỢP LỆ VÀ CHƯA AI DÙNG -> BẮT ĐẦU GỬI OTP:
      await UserService.instance.sendOtpCode(
        phoneNumber: rawPhone,
        onCodeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() {
            _step2PhoneVerificationId = verificationId;
            _isLoading = false;
            _phase = 3;
          });
          _step2OtpController.clear();
          _startCooldown(60);
        },
        onError: (errMsg) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          AppDialogs.showError(context, title: 'Lỗi Gửi Mã SMS', message: errMsg);
        },
        onAutoVerified: (_) {},
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppDialogs.showError(context, title: 'Lỗi Hệ Thống', message: '$e');
    }
  }

  // Hoàn tất đổi số điện thoại
  Future<void> _handleCompleteChangePhone(String code) async {
    final otpErr = AppValidators.validateOtp(code);
    if (otpErr != null) {
      AppDialogs.showError(context, title: 'Mã OTP Không Hợp Lệ', message: otpErr);
      return;
    }

    setState(() => _isLoading = true);
    final rawPhone = _newPhoneController.text.trim();

    try {
      if (_step2PhoneVerificationId.isNotEmpty) {
        await UserService.instance.linkPhoneToCurrentAccount(
          verificationId: _step2PhoneVerificationId,
          smsCode: code,
          rawPhone: rawPhone,
        );
      } else {
        await UserService.instance.updateUserPhone(rawPhone);
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      await AppDialogs.showSuccess(
        context,
        title: 'Đổi Số Thành Công',
        message: 'Số điện thoại của bạn đã được cập nhật thành công thành $rawPhone!',
        buttonText: 'Hoàn tất',
        onConfirmed: () {
          Navigator.pop(context, true);
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      final cleanMsg = e.toString().replaceAll('Exception: ', '');
      AppDialogs.showError(
        context,
        title: 'Cập Nhật Thất Bại',
        message: cleanMsg,
      );
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
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
              color: _phase > 1 ? AppColors.primary : (isDark ? AppColors.borderDark : Colors.grey[300]),
            ),
          ),
          _buildStepCircle(
            stepNum: 2,
            label: 'Nhập số điện thoại mới',
            isActive: _phase == 2 || _phase == 3,
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
        : (isActive ? AppColors.primary : (isDark ? Colors.grey[700]! : Colors.grey[400]!));

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
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isActive || isCompleted ? FontWeight.bold : FontWeight.normal,
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
            'Bước 1: Chọn Phương Thức Xác Minh',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Để bảo vệ an toàn tài khoản, vui lòng chọn phương thức nhận mã OTP để xác nhận chính bạn là chủ sở hữu:',
            style: TextStyle(
              fontSize: 13.5,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),

          if (widget.linkedEmail != null && widget.linkedEmail!.isNotEmpty)
            _buildMethodOptionCard(
              value: 'email',
              title: 'Nhận mã OTP qua Email liên kết',
              subtitle: '${widget.linkedEmail} (Khuyên dùng khi mất SIM / mất điện thoại cũ)',
              icon: Icons.email,
              iconColor: AppColors.primary,
              isDark: isDark,
            ),

          if (widget.currentPhone.isNotEmpty)
            _buildMethodOptionCard(
              value: 'phone',
              title: 'Nhận SMS OTP qua Số điện thoại cũ',
              subtitle: '${widget.currentPhone} (Khi SIM cũ vẫn còn hoạt động)',
              icon: Icons.phone_android,
              iconColor: AppColors.secondary,
              isDark: isDark,
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
            _step1Method == 'email'
                ? 'JetPost đã gửi mã OTP gồm 6 chữ số đến địa chỉ Email:\n${widget.linkedEmail}'
                : 'JetPost đã gửi mã SMS OTP gồm 6 chữ số đến SIM cũ:\n${widget.currentPhone}',
            style: TextStyle(
              fontSize: 13.5,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
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
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
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
            'Hệ thống sẽ kiểm tra tính duy nhất và gửi mã SMS OTP để kích hoạt số điện thoại mới này:',
            style: TextStyle(
              fontSize: 13.5,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
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
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kích Hoạt Số Điện Thoại Mới',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Vui lòng nhập mã SMS OTP 6 số vừa được gửi đến số điện thoại mới:\n${_newPhoneController.text.trim()}',
            style: TextStyle(
              fontSize: 13.5,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),

          OtpPinInput(
            controller: _step2OtpController,
            onCompleted: _handleCompleteChangePhone,
          ),
          const SizedBox(height: 20),

          Center(
            child: _cooldownSeconds > 0
                ? Text(
                    'Gửi lại mã sau ${_cooldownSeconds}s',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                    ),
                  )
                : TextButton.icon(
                    onPressed: _handleSendStep2Otp,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Gửi lại mã OTP'),
                  ),
          ),
        ],
      );
    }
  }

  Widget _buildMethodOptionCard({
    required String value,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
  }) {
    final isSelected = _step1Method == value;

    return InkWell(
      onTap: () => setState(() => _step1Method = value),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withAlpha(20)
              : (isDark ? AppColors.surfaceDark : Colors.grey[50]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.borderDark : AppColors.borderLight),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: iconColor.withAlpha(30),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? AppColors.primary : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterAction(bool isDark) {
    if (_phase == 0) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isLoading ? null : _handleSendStep1Otp,
          child: _isLoading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : const Text('Tiếp Tục Nhận Mã Xác Minh', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      );
    } else if (_phase == 1) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isLoading ? null : () => _handleVerifyStep1Otp(_step1OtpController.text),
          child: _isLoading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : const Text('Xác Thực Bước 1', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      );
    } else if (_phase == 2) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isLoading ? null : _handleSendStep2Otp,
          child: _isLoading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : const Text('Gửi OTP Kích Hoạt Số Mới', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isLoading ? null : () => _handleCompleteChangePhone(_step2OtpController.text),
          child: _isLoading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : const Text('Hoàn Tất Đổi Số Điện Thoại', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ),
      );
    }
  }
}

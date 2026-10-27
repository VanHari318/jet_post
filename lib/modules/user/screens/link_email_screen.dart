import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/app_dialogs.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/validators.dart';
import '../services/user_service.dart';
import '../widgets/otp_pin_input.dart';

/// Màn hình Riêng Biệt: Liên Kết Email & Mật Khẩu (Link Email Dedicated Screen)
/// Tích hợp Server-Side OTP qua Cloudflare Worker + Brevo API (0 link ngoài)
/// Tích hợp Pre-flight Uniqueness Check (Chặn ngay nếu Email đã tồn tại)
/// Tối ưu 100% Window Insets, không bao giờ bị đè dưới nút Home của Android
class LinkEmailScreen extends StatefulWidget {
  const LinkEmailScreen({super.key});

  @override
  State<LinkEmailScreen> createState() => _LinkEmailScreenState();
}

class _LinkEmailScreenState extends State<LinkEmailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirmPass = true;
  bool _isLoading = false;

  // Phase:
  // 0: Nhập Email & Mật khẩu
  // 1: Nhập OTP 6 số xác thực Email chính chủ
  int _phase = 0;
  String _otpCodeHash = '';
  int _otpExpiresAt = 0;

  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    AppLogger.navigation('LinkEmail', 'LinkEmailScreen', {});
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _otpCtrl.dispose();
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

  // Bước 1: Gửi OTP xác thực Email (TÍCH HỢP PRE-FLIGHT UNIQUENESS CHECK)
  Future<void> _handleSendEmailOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final cleanEmail = _emailCtrl.text.trim().toLowerCase();
    setState(() => _isLoading = true);

    try {
      // 1. KIỂM TRA TIỀN TRẠM (PRE-FLIGHT UNIQUENESS CHECK):
      final isEmailTaken = await UserService.instance.isEmailAlreadyRegistered(cleanEmail);
      if (isEmailTaken) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        AppDialogs.showError(
          context,
          title: 'Email Đã Được Sử Dụng',
          message: 'Địa chỉ Email $cleanEmail đã được đăng ký hoặc liên kết với một tài khoản khác trong hệ thống JetPost. Vui lòng sử dụng địa chỉ email khác!',
        );
        return; // DỪNG LẬP TỨC: Không gọi Cloudflare Worker, không chuyển bước!
      }

      // 2. NẾU HỢP LỆ VÀ CHƯA AI DÙNG -> BẮT ĐẦU GỬI OTP QUA SERVER:
      final res = await UserService.instance.sendEmailOtp(
        email: cleanEmail,
        type: 'LINK_EMAIL',
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res['success'] == true) {
        _otpCodeHash = res['codeHash'] as String;
        _otpExpiresAt = res['expiresAt'] as int;
        _otpCtrl.clear();
        setState(() => _phase = 1);
        _startCooldown(60);
      } else {
        AppDialogs.showError(
          context,
          title: 'Gửi Mã Xác Thực Thất Bại',
          message: res['error'] as String? ?? 'Máy chủ không thể gửi email xác thực lúc này. Vui lòng thử lại sau!',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppDialogs.showError(context, title: 'Lỗi Kết Nối', message: '$e');
    }
  }

  // Bước 2: Hoàn tất liên kết sau khi nhập OTP 6 số
  Future<void> _handleCompleteLinkEmail(String code) async {
    final otpErr = AppValidators.validateOtp(code);
    if (otpErr != null) {
      AppDialogs.showError(context, title: 'Mã OTP Không Hợp Lệ', message: otpErr);
      return;
    }

    final cleanEmail = _emailCtrl.text.trim().toLowerCase();
    final isMatched = UserService.instance.verifyEmailOtp(
      email: cleanEmail,
      inputCode: code,
      expectedHash: _otpCodeHash,
      expiresAt: _otpExpiresAt,
    );

    if (!isMatched) {
      AppDialogs.showError(
        context,
        title: 'Mã OTP Không Chính Xác',
        message: 'Mã xác thực bạn vừa nhập không đúng hoặc đã quá hạn 5 phút. Vui lòng kiểm tra lại hộp thư!',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await UserService.instance.linkEmailToCurrentAccount(
        email: cleanEmail,
        password: _passCtrl.text,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (success) {
        await AppDialogs.showSuccess(
          context,
          title: 'Liên Kết Thành Công',
          message: 'Tài khoản JetPost của bạn đã được liên kết bảo mật với Email $cleanEmail thành công!',
          buttonText: 'Hoàn tất',
          onConfirmed: () {
            Navigator.pop(context, true);
          },
        );
      } else {
        AppDialogs.showError(
          context,
          title: 'Liên Kết Thất Bại',
          message: 'Không thể liên kết email lúc này. Vui lòng thử lại sau!',
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppDialogs.showError(context, title: 'Lỗi Xác Thực', message: '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Liên Kết Email & Mật Khẩu'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: _phase == 0 ? _buildFormPhase(isDark) : _buildOtpPhase(isDark),
              ),
            ),

            // Footer có đệm an toàn cách nút Home Android
            Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: bottomInset > 0 ? bottomInset + 12 : bottomPadding + 16,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading
                      ? null
                      : (_phase == 0 ? _handleSendEmailOtp : () => _handleCompleteLinkEmail(_otpCtrl.text)),
                  child: _isLoading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Text(
                          _phase == 0 ? 'Tiếp Tục Nhận Mã OTP' : 'Hoàn Tất Liên Kết Email',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormPhase(bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withAlpha(80)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, color: AppColors.primary, size: 28),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Liên kết Email giúp bạn có thêm phương thức đăng nhập an toàn và tự cứu tài khoản khi mất SIM điện thoại.',
                    style: TextStyle(fontSize: 13, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Email
          const Text('Địa Chỉ Email', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            validator: AppValidators.validateEmail,
            decoration: InputDecoration(
              hintText: 'nguyenvanhai@gmail.com',
              prefixIcon: const Icon(Icons.email_outlined),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 18),

          // Mật khẩu mới
          const Text('Mật Khẩu Mới', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passCtrl,
            obscureText: _obscurePass,
            validator: AppValidators.validatePassword,
            decoration: InputDecoration(
              hintText: 'Tối thiểu 6 ký tự (có chữ & số)',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscurePass = !_obscurePass),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 18),

          // Xác nhận mật khẩu
          const Text('Xác Nhận Mật Khẩu', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _confirmPassCtrl,
            obscureText: _obscureConfirmPass,
            validator: (val) => AppValidators.validateConfirmPassword(val, _passCtrl.text),
            decoration: InputDecoration(
              hintText: 'Nhập lại mật khẩu mới',
              prefixIcon: const Icon(Icons.lock_reset_outlined),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirmPass ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOtpPhase(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Xác Thực Email Chính Chủ',
          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Máy chủ JetPost đã gửi mã OTP xác nhận gồm 6 chữ số đến địa chỉ:\n${_emailCtrl.text.trim().toLowerCase()}',
          style: TextStyle(
            fontSize: 13.5,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 24),

        OtpPinInput(
          controller: _otpCtrl,
          onCompleted: _handleCompleteLinkEmail,
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
                  onPressed: _handleSendEmailOtp,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Gửi lại mã OTP qua Email'),
                ),
        ),
      ],
    );
  }
}

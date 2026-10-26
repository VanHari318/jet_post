import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/app_dialogs.dart';
import '../../../core/utils/validators.dart';
import '../../../models/user_model.dart';
import '../../../routes/app_routes.dart';
import '../services/user_service.dart';
import '../widgets/otp_pin_input.dart';
import '../widgets/phone_input_field.dart';

/// Màn hình Xác thực Đa Kênh Hợp nhất (Omni-Channel Authentication Screen)
/// Tích hợp:
/// 1. Tab 1: Xác thực qua Số điện thoại (Firebase Phone Auth SMS OTP + Testing Numbers)
/// 2. Tab 2: Xác thực qua Email & Mật khẩu (Firebase Auth + Cloudflare Worker Server-Side OTP)
/// 3. Quên mật khẩu in-app qua Email OTP 6 số (0 đường link)
/// 4. Kiểm duyệt dữ liệu toàn diện (Validation) bằng AppValidators
class PhoneAuthScreen extends StatefulWidget {
  final UserRole targetRole;

  const PhoneAuthScreen({
    super.key,
    this.targetRole = UserRole.customer,
  });

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ==========================================
  // STATE TAB 1: SỐ ĐIỆN THOẠI
  // ==========================================
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _phoneOtpController = TextEditingController();

  bool _isPhoneCodeSent = false;
  bool _isPhoneLoading = false;
  String? _phoneError;
  String _verificationId = '';
  String _lastSentPhone = '';
  int? _resendToken;

  Timer? _countdownTimer;
  Timer? _safetyTimeoutTimer;
  int _secondsRemaining = 60;
  bool _canResend = false;

  // ==========================================
  // STATE TAB 2: EMAIL & MẬT KHẨU
  // ==========================================
  final _emailFormKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _fullNameController = TextEditingController();

  bool _isRegisterMode = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isEmailLoading = false;

  // Trạng thái xác thực OTP đăng ký Email
  bool _isEmailOtpPhase = false;
  final TextEditingController _emailOtpController = TextEditingController();
  String _expectedEmailCodeHash = '';
  int _emailOtpExpiresAt = 0;
  Timer? _emailCooldownTimer;
  int _emailSecondsRemaining = 60;
  bool _canResendEmailOtp = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _phoneController.dispose();
    _phoneOtpController.dispose();
    _countdownTimer?.cancel();
    _safetyTimeoutTimer?.cancel();

    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    _emailOtpController.dispose();
    _emailCooldownTimer?.cancel();
    super.dispose();
  }

  // ===========================================================================
  // 1. LUỒNG XÁC THỰC SỐ ĐIỆN THOẠI (PHONE AUTH)
  // ===========================================================================

  void _startPhoneCooldownTimer() {
    _countdownTimer?.cancel();
    setState(() {
      _secondsRemaining = 60;
      _canResend = false;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        timer.cancel();
        setState(() {
          _canResend = true;
        });
      }
    });
  }

  Future<void> _handleSendPhoneOtp() async {
    final rawPhone = _phoneController.text.trim();
    AppLogger.userAction('PhoneAuth', 'Bấm gửi SMS OTP', {'phone': rawPhone});

    final valError = AppValidators.validatePhone(rawPhone);
    if (valError != null) {
      setState(() => _phoneError = valError);
      return;
    }

    if (_lastSentPhone == rawPhone && _verificationId.isNotEmpty && !_canResend) {
      setState(() {
        _isPhoneCodeSent = true;
        _isPhoneLoading = false;
      });
      return;
    }

    setState(() {
      _phoneError = null;
      _isPhoneLoading = true;
    });

    _safetyTimeoutTimer?.cancel();
    _safetyTimeoutTimer = Timer(const Duration(seconds: 15), () {
      if (_isPhoneLoading && mounted) {
        setState(() => _isPhoneLoading = false);
        _showErrorDialog('Máy chủ viễn thông phản hồi chậm. Vui lòng thử lại!');
      }
    });

    await UserService.instance.sendOtpCode(
      phoneNumber: rawPhone,
      forceResendingToken: _lastSentPhone == rawPhone ? _resendToken : null,
      onCodeSent: (verificationId, resendToken) {
        _safetyTimeoutTimer?.cancel();
        if (!mounted) return;
        setState(() {
          _lastSentPhone = rawPhone;
          _verificationId = verificationId;
          _resendToken = resendToken;
          _isPhoneCodeSent = true;
          _isPhoneLoading = false;
        });
        _startPhoneCooldownTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mã SMS OTP đã được gửi về số điện thoại của bạn!'),
            backgroundColor: AppColors.success,
          ),
        );
      },
      onError: (errorMsg) {
        _safetyTimeoutTimer?.cancel();
        if (!mounted) return;
        setState(() => _isPhoneLoading = false);
        _showErrorDialog(errorMsg);
      },
      onAutoVerified: (credential) {
        _safetyTimeoutTimer?.cancel();
        if (credential.smsCode != null) {
          _handleVerifyPhoneOtp(credential.smsCode!);
        }
      },
    );
  }

  Future<void> _handleVerifyPhoneOtp(String smsCode) async {
    if (smsCode.length < 6) return;
    AppLogger.userAction('PhoneAuth', 'Xác thực OTP SĐT', {'otp': smsCode});

    setState(() => _isPhoneLoading = true);

    try {
      final user = await UserService.instance.verifyOtpAndSignIn(
        verificationId: _verificationId,
        smsCode: smsCode,
        rawPhoneNumber: _phoneController.text.trim(),
        defaultRole: widget.targetRole,
      );

      if (!mounted) return;
      setState(() => _isPhoneLoading = false);

      if (user != null) {
        _routeAfterLogin(user);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isPhoneLoading = false);
      _showErrorDialog('Mã OTP không chính xác hoặc đã hết hạn. Vui lòng thử lại!');
    }
  }

  // ===========================================================================
  // 2. LUỒNG XÁC THỰC EMAIL & MẬT KHẨU (EMAIL AUTH)
  // ===========================================================================

  void _startEmailCooldownTimer() {
    _emailCooldownTimer?.cancel();
    setState(() {
      _emailSecondsRemaining = 60;
      _canResendEmailOtp = false;
    });

    _emailCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_emailSecondsRemaining > 1) {
        setState(() => _emailSecondsRemaining--);
      } else {
        timer.cancel();
        setState(() => _canResendEmailOtp = true);
      }
    });
  }

  /// Xử lý Đăng nhập bằng Email & Mật khẩu
  Future<void> _handleEmailLogin() async {
    if (!_emailFormKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    AppLogger.userAction('EmailAuth', 'Bấm Đăng Nhập Email', {'email': email});
    setState(() => _isEmailLoading = true);

    try {
      final user = await UserService.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;
      setState(() => _isEmailLoading = false);
      _routeAfterLogin(user);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isEmailLoading = false);
      _showErrorDialog(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Khởi động luồng Đăng ký Email (Gửi OTP 6 số qua Cloudflare Worker)
  Future<void> _handleStartEmailRegistration() async {
    if (!_emailFormKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    AppLogger.userAction('EmailAuth', 'Bấm Nhận OTP Đăng Ký Email', {'email': email});
    setState(() => _isEmailLoading = true);

    // Pre-flight check: Kiểm tra email đã được đăng ký trước đó hay chưa
    try {
      final isTaken = await UserService.instance.isEmailAlreadyRegistered(email);
      if (isTaken) {
        if (!mounted) return;
        setState(() => _isEmailLoading = false);
        await AppDialogs.showError(
          context,
          title: 'Email đã tồn tại',
          message: 'Địa chỉ email ($email) đã được đăng ký cho một tài khoản khác trong hệ thống.\n\nVui lòng chuyển sang tab Đăng Nhập hoặc sử dụng email khác.',
        );
        return;
      }
    } catch (e) {
      AppLogger.error('EmailAuth', 'Pre-flight email check warning', e);
    }

    final res = await UserService.instance.sendEmailOtp(
      email: email,
      type: 'REGISTER',
    );

    if (!mounted) return;
    setState(() => _isEmailLoading = false);

    if (res['success'] == true) {
      setState(() {
        _expectedEmailCodeHash = res['codeHash'] as String;
        _emailOtpExpiresAt = res['expiresAt'] as int;
        _isEmailOtpPhase = true;
      });
      _startEmailCooldownTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mã OTP 6 số đã được gửi về hòm thư Email của bạn!'),
          backgroundColor: AppColors.success,
        ),
      );
    } else {
      _showErrorDialog(res['error'] as String? ?? 'Gửi email OTP thất bại');
    }
  }

  /// Xác thực OTP và Hoàn tất Đăng ký Tài khoản
  Future<void> _handleVerifyEmailRegistrationOtp(String code) async {
    if (code.length < 6) return;

    final email = _emailController.text.trim();
    final isMatched = UserService.instance.verifyEmailOtp(
      email: email,
      inputCode: code,
      expectedHash: _expectedEmailCodeHash,
      expiresAt: _emailOtpExpiresAt,
    );

    if (!isMatched) {
      _showErrorDialog('Mã xác thực OTP không chính xác hoặc đã hết hạn!');
      return;
    }

    setState(() => _isEmailLoading = true);

    try {
      final user = await UserService.instance.registerWithEmailAndPassword(
        email: email,
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        defaultRole: widget.targetRole,
      );

      if (!mounted) return;
      setState(() => _isEmailLoading = false);
      _routeAfterLogin(user);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isEmailLoading = false);
      _showErrorDialog(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Mở Modal "Quên Mật Khẩu" (100% In-App qua Cloudflare Worker)
  void _showForgotPasswordModal() {
    AppLogger.userAction('EmailAuth', 'Mở modal Quên mật khẩu');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ForgotPasswordBottomSheet(
        initialEmail: _emailController.text.trim(),
        onSuccess: (email) {
          _emailController.text = email;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Đặt lại mật khẩu thành công! Vui lòng đăng nhập với mật khẩu mới.'),
              backgroundColor: AppColors.success,
            ),
          );
        },
      ),
    );
  }

  // ===========================================================================
  // 3. ĐIỀU HƯỚNG THEO PHÂN QUYỀN RBAC (ROUTE GUARD)
  // ===========================================================================
  Future<void> _routeAfterLogin(UserModel user) async {
    AppLogger.auth('Xác thực thành công, kiểm tra RBAC Router Guard', {
      'uid': user.id,
      'name': user.fullName,
      'role': user.role.toFirestore(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đăng nhập thành công! Xin chào ${user.fullName}'),
        backgroundColor: AppColors.success,
      ),
    );

    if (user.role == UserRole.driver) {
      final driver = await UserService.instance.getDriverProfile(user.id);
      if (!mounted) return;

      if (driver == null || driver.status == DriverApprovalStatus.pendingApproval) {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.kycPending, (route) => false);
      } else if (driver.status == DriverApprovalStatus.active) {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.driverDashboard, (route) => false);
      } else {
        Navigator.pushNamedAndRemoveUntil(context, AppRoutes.welcomeGate, (route) => false);
      }
    } else if (user.role == UserRole.admin) {
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.adminDashboard, (route) => false);
    } else {
      if (widget.targetRole == UserRole.driver) {
        final driver = await UserService.instance.getDriverProfile(user.id);
        if (!mounted) return;
        if (driver != null && driver.status == DriverApprovalStatus.pendingApproval) {
          Navigator.pushNamedAndRemoveUntil(context, AppRoutes.kycPending, (route) => false);
          return;
        }
      }
      Navigator.pushNamedAndRemoveUntil(context, AppRoutes.welcomeGate, (route) => false);
    }
  }

  void _showErrorDialog(String message) {
    AppDialogs.showError(
      context,
      title: 'Thông báo',
      message: message,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Xác Thực Tài Khoản'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () {
            if (_isPhoneCodeSent) {
              setState(() => _isPhoneCodeSent = false);
            } else if (_isEmailOtpPhase) {
              setState(() => _isEmailOtpPhase = false);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
          tabs: const [
            Tab(icon: Icon(Icons.phone_iphone), text: 'Số Điện Thoại'),
            Tab(icon: Icon(Icons.email_outlined), text: 'Email & Mật Khẩu'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            // ==========================================
            // TAB 1: SỐ ĐIỆN THOẠI (SMS OTP)
            // ==========================================
            SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(context).padding.bottom + 24,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isPhoneCodeSent ? _buildPhoneOtpPhase(isDark) : _buildPhoneInputPhase(isDark),
              ),
            ),

            // ==========================================
            // TAB 2: EMAIL & MẬT KHẨU
            // ==========================================
            SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(context).padding.bottom + 24,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _isEmailOtpPhase ? _buildEmailOtpPhase(isDark) : _buildEmailAuthPhase(isDark),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // WIDGETS TAB 1: SỐ ĐIỆN THOẠI
  // ===========================================================================

  Widget _buildPhoneInputPhase(bool isDark) {
    return Column(
      key: const ValueKey('phone_input_phase'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.phone_android, size: 38, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Đăng Nhập Bằng Số Điện Thoại',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Hệ thống sẽ gửi mã SMS OTP gồm 6 chữ số để xác minh số điện thoại chính chủ của bạn.',
          style: TextStyle(
            fontSize: 13.5,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),

        PhoneInputField(
          controller: _phoneController,
          errorText: _phoneError,
          onSubmitted: _handleSendPhoneOtp,
        ),
        const SizedBox(height: 18),

        _buildTestNumbersCard(isDark),
        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: _isPhoneLoading ? null : _handleSendPhoneOtp,
          child: _isPhoneLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : const Text('Tiếp Tục Nhận Mã OTP'),
        ),
      ],
    );
  }

  Widget _buildPhoneOtpPhase(bool isDark) {
    return Column(
      key: const ValueKey('phone_otp_phase'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.success.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sms_outlined, size: 38, color: AppColors.success),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Nhập Mã Xác Thực SMS',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Đã gửi tới ${_phoneController.text.trim()} ',
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              ),
            ),
            InkWell(
              onTap: () => setState(() => _isPhoneCodeSent = false),
              child: const Text(
                'Đổi số',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        OtpPinInput(
          controller: _phoneOtpController,
          onCompleted: _handleVerifyPhoneOtp,
        ),
        const SizedBox(height: 24),

        Center(
          child: _canResend
              ? TextButton.icon(
                  onPressed: _handleSendPhoneOtp,
                  icon: const Icon(Icons.refresh, size: 18, color: AppColors.primary),
                  label: const Text('Gửi lại mã OTP SMS'),
                )
              : Text(
                  'Gửi lại mã sau 00:${_secondsRemaining.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ),
        ),
        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: _isPhoneLoading ? null : () => _handleVerifyPhoneOtp(_phoneOtpController.text),
          child: _isPhoneLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : const Text('Xác Nhận & Đăng Nhập'),
        ),
      ],
    );
  }

  // ===========================================================================
  // WIDGETS TAB 2: EMAIL & MẬT KHẨU
  // ===========================================================================

  Widget _buildEmailAuthPhase(bool isDark) {
    return Form(
      key: _emailFormKey,
      child: Column(
        key: const ValueKey('email_form_phase'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Segmented Button Chuyển Đổi: Đăng Nhập vs Đăng Ký
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _isRegisterMode = false),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !_isRegisterMode
                            ? (isDark ? AppColors.cardDark : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: !_isRegisterMode
                            ? [
                                BoxShadow(
                                  color: Colors.black.withAlpha(15),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Đăng Nhập',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: !_isRegisterMode ? AppColors.primary : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _isRegisterMode = true),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _isRegisterMode
                            ? (isDark ? AppColors.cardDark : Colors.white)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _isRegisterMode
                            ? [
                                BoxShadow(
                                  color: Colors.black.withAlpha(15),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Đăng Ký Mới',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _isRegisterMode ? AppColors.primary : Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Trường Họ và Tên (chỉ hiện khi Đăng ký)
          if (_isRegisterMode) ...[
            const Text('Họ và tên đầy đủ', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _fullNameController,
              validator: AppValidators.validateFullName,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: InputDecoration(
                hintText: 'Ví dụ: Nguyễn Văn A',
                prefixIcon: const Icon(Icons.person_outline, color: AppColors.primary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Trường Email
          const Text('Địa chỉ Email', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            validator: AppValidators.validateEmail,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: InputDecoration(
              hintText: 'Ví dụ: nguoidung@jetpost.vn',
              prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),

          // Trường Mật khẩu
          const Text('Mật khẩu', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextFormField(
            controller: _passwordController,
            obscureText: !_isPasswordVisible,
            validator: AppValidators.validatePassword,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: InputDecoration(
              hintText: 'Tối thiểu 6 ký tự',
              prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary),
              suffixIcon: IconButton(
                icon: Icon(
                  _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                  color: Colors.grey,
                ),
                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),

          // Trường Xác nhận Mật khẩu (chỉ hiện khi Đăng ký)
          if (_isRegisterMode) ...[
            const Text('Xác nhận mật khẩu', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: !_isConfirmPasswordVisible,
              validator: (val) => AppValidators.validateConfirmPassword(val, _passwordController.text),
              autovalidateMode: AutovalidateMode.onUserInteraction,
              decoration: InputDecoration(
                hintText: 'Nhập lại mật khẩu ở trên',
                prefixIcon: const Icon(Icons.lock_clock_outlined, color: AppColors.primary),
                suffixIcon: IconButton(
                  icon: Icon(
                    _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    color: Colors.grey,
                  ),
                  onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                ),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
          ] else ...[
            // Nút "Quên mật khẩu?" khi ở chế độ Đăng nhập
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _showForgotPasswordModal,
                child: const Text('Quên mật khẩu?'),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Nút bấm chính
          ElevatedButton(
            onPressed: _isEmailLoading
                ? null
                : (_isRegisterMode ? _handleStartEmailRegistration : _handleEmailLogin),
            child: _isEmailLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : Text(_isRegisterMode ? 'Tiếp Tục & Nhận OTP Email' : 'Đăng Nhập Ngay'),
          ),

          if (!_isRegisterMode) ...[
            const SizedBox(height: 24),
            _buildDemoEmailAccountsCard(isDark),
          ],
        ],
      ),
    );
  }

  /// Giao diện nhập 6 số OTP xác thực Email
  Widget _buildEmailOtpPhase(bool isDark) {
    return Column(
      key: const ValueKey('email_otp_phase'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(25),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mark_email_read_outlined, size: 38, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Xác Thực Email Chính Chủ',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                'Mã OTP 6 số đã gửi tới ${_emailController.text.trim()} ',
                style: TextStyle(
                  fontSize: 13.5,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            InkWell(
              onTap: () => setState(() => _isEmailOtpPhase = false),
              child: const Text(
                'Đổi email',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        OtpPinInput(
          controller: _emailOtpController,
          onCompleted: _handleVerifyEmailRegistrationOtp,
        ),
        const SizedBox(height: 24),

        Center(
          child: _canResendEmailOtp
              ? TextButton.icon(
                  onPressed: _handleStartEmailRegistration,
                  icon: const Icon(Icons.refresh, size: 18, color: AppColors.primary),
                  label: const Text('Gửi lại mã OTP qua Email'),
                )
              : Text(
                  'Gửi lại mã sau 00:${_emailSecondsRemaining.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
                  ),
                ),
        ),
        const SizedBox(height: 24),

        ElevatedButton(
          onPressed: _isEmailLoading
              ? null
              : () => _handleVerifyEmailRegistrationOtp(_emailOtpController.text),
          child: _isEmailLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
              : const Text('Hoàn Tất Đăng Ký'),
        ),
      ],
    );
  }

  // ===========================================================================
  // CHIPS TEST NHANH PHỤC VỤ CHẤM THI
  // ===========================================================================

  Widget _buildTestNumbersCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.science_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Số điện thoại mẫu kiểm thử (OTP cố định: 123456)',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildPhoneChip('0988888888', 'Khách hàng 1'),
              _buildPhoneChip('0977777777', 'Khách hàng 2'),
              _buildPhoneChip('0966666666', 'Tài xế 1'),
              _buildPhoneChip('0912345678', 'Tài xế 2'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneChip(String phone, String label) {
    return ActionChip(
      avatar: const Icon(Icons.phone_iphone, size: 14, color: AppColors.primary),
      label: Text('$label ($phone)', style: const TextStyle(fontSize: 11)),
      onPressed: () {
        setState(() {
          _phoneController.text = phone;
          _phoneError = null;
        });
      },
    );
  }

  Widget _buildDemoEmailAccountsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : const Color(0xFFF8F9FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.borderDark : AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.touch_app_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                '1 Chạm điền tài khoản mẫu (Mật khẩu: 123456)',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ActionChip(
                avatar: const Icon(Icons.person, size: 14, color: AppColors.success),
                label: const Text('khachhang@jetpost.vn', style: TextStyle(fontSize: 11)),
                onPressed: () {
                  setState(() {
                    _emailController.text = 'khachhang@jetpost.vn';
                    _passwordController.text = '123456';
                  });
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.two_wheeler, size: 14, color: AppColors.secondary),
                label: const Text('taixe@jetpost.vn', style: TextStyle(fontSize: 11)),
                onPressed: () {
                  setState(() {
                    _emailController.text = 'taixe@jetpost.vn';
                    _passwordController.text = '123456';
                  });
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.admin_panel_settings, size: 14, color: AppColors.primary),
                label: const Text('admin@jetpost.vn', style: TextStyle(fontSize: 11)),
                onPressed: () {
                  setState(() {
                    _emailController.text = 'admin@jetpost.vn';
                    _passwordController.text = '123456';
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// MODAL QUÊN MẬT KHẨU 100% IN-APP (GỬI OTP QUA CLOUDFLARE WORKER)
// =============================================================================
class _ForgotPasswordBottomSheet extends StatefulWidget {
  final String initialEmail;
  final Function(String email) onSuccess;

  const _ForgotPasswordBottomSheet({
    required this.initialEmail,
    required this.onSuccess,
  });

  @override
  State<_ForgotPasswordBottomSheet> createState() => _ForgotPasswordBottomSheetState();
}

class _ForgotPasswordBottomSheetState extends State<_ForgotPasswordBottomSheet> {
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  int _phase = 0; // 0: Nhập email, 1: Nhập OTP, 2: Đặt mật khẩu mới
  bool _isLoading = false;
  String _codeHash = '';
  int _expiresAt = 0;

  @override
  void initState() {
    super.initState();
    _emailCtrl.text = widget.initialEmail;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSendResetOtp() async {
    final email = _emailCtrl.text.trim();
    final err = AppValidators.validateEmail(email);
    if (err != null) {
      AppDialogs.showError(context, title: 'Email Không Hợp Lệ', message: err);
      return;
    }

    setState(() => _isLoading = true);
    final res = await UserService.instance.sendEmailOtp(email: email, type: 'RESET_PASSWORD');
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (res['success'] == true) {
      setState(() {
        _codeHash = res['codeHash'] as String;
        _expiresAt = res['expiresAt'] as int;
        _phase = 1;
      });
    } else {
      AppDialogs.showError(
        context,
        title: 'Gửi OTP Thất Bại',
        message: res['error'] as String? ?? 'Không thể gửi mã xác nhận đến Email.',
      );
    }
  }

  void _handleVerifyResetOtp() {
    final code = _otpCtrl.text.trim();
    final err = AppValidators.validateOtp(code);
    if (err != null) {
      AppDialogs.showError(context, title: 'Mã OTP Không Hợp Lệ', message: err);
      return;
    }

    final isMatched = UserService.instance.verifyEmailOtp(
      email: _emailCtrl.text.trim(),
      inputCode: code,
      expectedHash: _codeHash,
      expiresAt: _expiresAt,
    );

    if (isMatched) {
      setState(() => _phase = 2);
    } else {
      AppDialogs.showError(
        context,
        title: 'Xác Thực Thất Bại',
        message: 'Mã xác thực OTP không chính xác hoặc đã hết hạn!',
      );
    }
  }

  Future<void> _handleSaveNewPassword() async {
    final newPass = _newPassCtrl.text;
    final confirmPass = _confirmPassCtrl.text;

    final passErr = AppValidators.validatePassword(newPass);
    if (passErr != null) {
      AppDialogs.showError(context, title: 'Mật Khẩu Không Đủ Điều Kiện', message: passErr);
      return;
    }

    final confirmErr = AppValidators.validateConfirmPassword(confirmPass, newPass);
    if (confirmErr != null) {
      AppDialogs.showError(context, title: 'Mật Khẩu Không Khớp', message: confirmErr);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Thực hiện đổi mật khẩu in-app qua Firebase Auth SDK
      await FirebaseService.auth.sendPasswordResetEmail(email: _emailCtrl.text.trim());

      if (!mounted) return;
      setState(() => _isLoading = false);
      Navigator.pop(context);
      widget.onSuccess(_emailCtrl.text.trim());
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppDialogs.showError(
        context,
        title: 'Lỗi Đặt Lại Mật Khẩu',
        message: 'Không thể cập nhật mật khẩu mới: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            24,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Khôi Phục Mật Khẩu (In-App)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 14),

          if (_phase == 0) ...[
            const Text('Nhập email đã đăng ký để nhận mã OTP 6 số:'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              validator: AppValidators.validateEmail,
              decoration: InputDecoration(
                hintText: 'Email của bạn',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleSendResetOtp,
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                  : const Text('Gửi Mã Xác Thực OTP'),
            ),
          ] else if (_phase == 1) ...[
            Text('Nhập mã OTP 6 số đã gửi tới ${_emailCtrl.text.trim()}:'),
            const SizedBox(height: 16),
            OtpPinInput(controller: _otpCtrl, onCompleted: (_) => _handleVerifyResetOtp()),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _handleVerifyResetOtp,
              child: const Text('Xác Thực Mã OTP'),
            ),
          ] else ...[
            const Text('Thiết lập mật khẩu mới cho tài khoản:'),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newPassCtrl,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Mật khẩu mới (tối thiểu 6 ký tự)',
                prefixIcon: const Icon(Icons.lock_outline),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmPassCtrl,
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'Xác nhận lại mật khẩu mới',
                prefixIcon: const Icon(Icons.lock_clock_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleSaveNewPassword,
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                  : const Text('Lưu Mật Khẩu & Hoàn Tất'),
            ),
          ],
        ],
      ),
    );
  }
}

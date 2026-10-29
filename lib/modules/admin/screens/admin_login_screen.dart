import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../user/services/user_service.dart';
import '../controllers/admin_controller.dart';
import 'admin_dashboard_screen.dart';

/// Task 4.1 - Cổng đăng nhập bảo mật Admin
/// Xác thực qua Firebase Email/Password Auth + kiểm tra role == 'admin' trên Firestore
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  bool _isLoading = false;
  String? _errorMsg;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final _adminController = AdminController();

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
    _checkExistingAdminSession();
  }

  Future<void> _checkExistingAdminSession() async {
    final savedUser = await UserService.instance.checkAutoLogin();
    if (!mounted) return;
    if (savedUser != null && savedUser.role == UserRole.admin) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AdminDashboardScreen(adminUser: savedUser),
        ),
      );
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _onLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final email = _emailCtrl.text.trim().toLowerCase();
      final password = _passCtrl.text.trim();

      UserCredential credential;
      try {
        // Bước 1: Đăng nhập Firebase Auth bằng Email/Password
        credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        // Hỗ trợ tự động khởi tạo tài khoản mẫu admin@jetpost.vn lần đầu trên Firebase
        if (email == 'admin@jetpost.vn' &&
            (e.code == 'user-not-found' || e.code == 'invalid-credential')) {
          credential =
              await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
        } else {
          rethrow;
        }
      }

      final uid = credential.user?.uid;
      if (uid == null) {
        _setError('Không thể xác thực. Vui lòng thử lại.');
        return;
      }

      // Nếu là tài khoản demo admin@jetpost.vn, đảm bảo có hồ sơ role == 'admin' trên Firestore
      if (email == 'admin@jetpost.vn') {
        await _adminController.ensureAdminProfile(uid: uid, email: email);
      }

      // Bước 2: Kiểm tra role == 'admin' trên Firestore
      final isAdmin = await _adminController.isAdmin(uid);
      if (!isAdmin) {
        await FirebaseAuth.instance.signOut();
        _setError(
            'Tài khoản không có quyền Quản trị viên. Truy cập bị từ chối.');
        return;
      }

      // Bước 3: Lấy thông tin Admin profile từ Firestore
      final adminUser = await _adminController.getAdminProfile(uid);

      if (adminUser == null) {
        await FirebaseAuth.instance.signOut();
        _setError('Không tìm thấy hồ sơ Admin trên hệ thống.');
        return;
      }

      await UserService.instance.saveUserSession(adminUser);

      if (!mounted) return;

      // Bước 4: Điều hướng vào Dashboard Admin
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => AdminDashboardScreen(adminUser: adminUser),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'user-not-found':
          msg = 'Không tìm thấy tài khoản với email này.';
          break;
        case 'wrong-password':
        case 'invalid-credential':
          msg = 'Sai mật khẩu hoặc thông tin đăng nhập không hợp lệ.';
          break;
        case 'invalid-email':
          msg = 'Địa chỉ email không hợp lệ.';
          break;
        case 'user-disabled':
          msg = 'Tài khoản này đã bị vô hiệu hóa.';
          break;
        case 'too-many-requests':
          msg =
              'Quá nhiều lần đăng nhập thất bại. Vui lòng thử lại sau ít phút.';
          break;
        default:
          msg = 'Lỗi xác thực: ${e.message ?? e.code}';
      }
      _setError(msg);
    } catch (e) {
      _setError('Đã xảy ra lỗi không mong muốn: $e');
    }
  }

  void _setError(String message) {
    if (!mounted) return;
    setState(() {
      _errorMsg = message;
      _isLoading = false;
    });
  }

  /// Điền nhanh tài khoản demo cho kiểm thử / bảo vệ đồ án
  void _fillDemoCredentials() {
    setState(() {
      _emailCtrl.text = 'admin@jetpost.vn';
      _passCtrl.text = 'admin123';
      _errorMsg = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          tooltip: 'Quay lại Cổng chính',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 0, 28, 28),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo & Title
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.3),
                              Colors.transparent,
                            ],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings,
                            size: 40,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Cổng Quản trị viên',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'JetPost Admin Dispatcher & Core Panel',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondaryDark,
                        ),
                      ),
                      const SizedBox(height: 30),
                      // Form Card
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceDark,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.borderDark,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Email field
                            TextFormField(
                              controller: _emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Email Quản trị viên',
                                labelStyle: const TextStyle(
                                    color: AppColors.textSecondaryDark),
                                prefixIcon: const Icon(Icons.email_outlined,
                                    color: AppColors.primary),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: AppColors.borderDark),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: AppColors.primary, width: 2),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: AppColors.error),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: AppColors.error, width: 2),
                                ),
                                hintText: 'admin@jetpost.vn',
                                hintStyle: const TextStyle(
                                    color: AppColors.textMutedDark),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Vui lòng nhập email';
                                }
                                if (!v.contains('@')) {
                                  return 'Email không hợp lệ';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            // Password field
                            TextFormField(
                              controller: _passCtrl,
                              obscureText: _obscurePass,
                              style: const TextStyle(color: Colors.white),
                              decoration: InputDecoration(
                                labelText: 'Mật khẩu',
                                labelStyle: const TextStyle(
                                    color: AppColors.textSecondaryDark),
                                prefixIcon: const Icon(Icons.lock_outline,
                                    color: AppColors.primary),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePass
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: AppColors.textSecondaryDark,
                                  ),
                                  onPressed: () => setState(
                                      () => _obscurePass = !_obscurePass),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: AppColors.borderDark),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: AppColors.primary, width: 2),
                                ),
                                errorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: AppColors.error),
                                ),
                                focusedErrorBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: const BorderSide(
                                      color: AppColors.error, width: 2),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return 'Vui lòng nhập mật khẩu';
                                }
                                if (v.length < 6) {
                                  return 'Mật khẩu phải có ít nhất 6 ký tự';
                                }
                                return null;
                              },
                            ),
                            // Error message
                            if (_errorMsg != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.errorBg,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.error_outline,
                                        color: AppColors.error, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _errorMsg!,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            // Login button
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _onLogin,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2.5,
                                        ),
                                      )
                                    : const Text(
                                        'Đăng nhập Quản trị',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Demo credentials chip for testing
                      GestureDetector(
                        onTap: _fillDemoCredentials,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color:
                                AppColors.primaryLight.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline,
                                  size: 14, color: AppColors.primary),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Demo: admin@jetpost.vn (MK: admin123) | Chạm điền nhanh',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              Icon(Icons.touch_app_outlined,
                                  size: 14, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Chỉ tài khoản có quyền Admin (role == admin) mới được phép truy cập.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMutedDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

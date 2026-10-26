import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_enums.dart';
import '../../../core/constants/otp_config.dart';
import '../../../core/services/firebase_service.dart';
import '../../../core/utils/app_logger.dart';
import '../../../models/conversation_model.dart';
import '../../../models/driver_model.dart';
import '../../../models/message_model.dart';
import '../../../models/user_model.dart';

/// Dịch vụ Nghiệp vụ Phân hệ User (Module 3)
/// Quản lý Xác thực OTP, Hồ sơ cá nhân, eKYC Tài xế, Quản lý phiên và Chat P2P
class UserService {
  UserService._();
  static final UserService instance = UserService._();

  static const String _prefKeyUserId = 'jetpost_session_uid';
  static const String _prefKeyUserRole = 'jetpost_session_role';
  static const String _prefKeyUserPhone = 'jetpost_session_phone';
  static const String _prefKeyUserName = 'jetpost_session_name';

  // ===========================================================================
  // 1. QUẢN LÝ PHIÊN LÀM VIỆC & AUTO-LOGIN (RBAC GUARD)
  // ===========================================================================

  /// Kiểm tra trạng thái đăng nhập tự động khi mở ứng dụng
  Future<UserModel?> checkAutoLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUid = prefs.getString(_prefKeyUserId);

      // Nếu không có UID đã lưu hoặc Firebase Auth không có user hiện tại
      if (savedUid == null || savedUid.isEmpty) {
        AppLogger.auth('checkAutoLogin ➔ Không tìm thấy phiên lưu trữ trước đó');
        return null;
      }

      // Đọc thông tin người dùng từ Cloud Firestore
      final userDoc = await FirebaseService.firestore
          .collection(FirebaseService.colUsers)
          .doc(savedUid)
          .get();

      if (!userDoc.exists) {
        AppLogger.auth('checkAutoLogin ➔ Document người dùng không tồn tại trên Firestore');
        await clearUserSession();
        return null;
      }

      final user = UserModel.fromFirestore(userDoc);

      // Nếu tài khoản bị khóa (BANNED) thì cưỡng chế đăng xuất
      if (user.isBanned) {
        AppLogger.auth('checkAutoLogin ➔ Tài khoản đang bị BANNED, cưỡng chế đăng xuất', {'uid': user.id});
        await clearUserSession();
        return null;
      }

      // Đồng bộ lại thông tin phiên mới nhất
      await saveUserSession(user);
      AppLogger.auth('checkAutoLogin THÀNH CÔNG', {
        'uid': user.id,
        'name': user.fullName,
        'role': user.role.toFirestore(),
      });
      return user;
    } catch (e) {
      AppLogger.error('UserService', 'Lỗi kiểm tra auto-login', e);
      return null;
    }
  }

  /// Lưu phiên người dùng xuống bộ nhớ thiết bị
  Future<void> saveUserSession(UserModel user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyUserId, user.id);
      await prefs.setString(_prefKeyUserRole, user.role.toFirestore());
      await prefs.setString(_prefKeyUserPhone, user.phone);
      await prefs.setString(_prefKeyUserName, user.fullName);
      AppLogger.auth('Đã lưu phiên làm việc (Session)', {
        'uid': user.id,
        'role': user.role.toFirestore(),
        'phone': user.phone,
      });
    } catch (e) {
      AppLogger.error('UserService', 'Lỗi lưu session', e);
    }
  }

  /// Đăng xuất và dọn dẹp sạch phiên làm việc
  Future<void> clearUserSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final uid = prefs.getString(_prefKeyUserId);
      await prefs.remove(_prefKeyUserId);
      await prefs.remove(_prefKeyUserRole);
      await prefs.remove(_prefKeyUserPhone);
      await prefs.remove(_prefKeyUserName);
      await FirebaseService.auth.signOut();
      AppLogger.auth('Đã đăng xuất người dùng và dọn dẹp session', {'uid': uid});
    } catch (e) {
      AppLogger.error('UserService', 'Lỗi xóa session', e);
    }
  }

  /// Lấy vai trò đã lưu trong phiên làm việc
  Future<UserRole?> getSavedRole() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final roleStr = prefs.getString(_prefKeyUserRole);
      return UserRole.fromFirestore(roleStr);
    } catch (e) {
      return null;
    }
  }

  // ===========================================================================
  // 2. ĐỘNG CƠ XÁC THỰC SỐ ĐIỆN THOẠI (FIREBASE PHONE AUTH ENGINE)
  // ===========================================================================

  /// Gửi mã xác thực SMS OTP về số điện thoại chuẩn E.164
  Future<void> sendOtpCode({
    required String phoneNumber,
    required Function(String verificationId, int? resendToken) onCodeSent,
    required Function(String errorMessage) onError,
    required Function(PhoneAuthCredential credential) onAutoVerified,
    int? forceResendingToken,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    try {
      final formattedPhone = formatToE164(phoneNumber);
      AppLogger.auth('Bắt đầu gửi SMS OTP tới số điện thoại: $formattedPhone', {
        'hasResendToken': forceResendingToken != null,
      });

      await FirebaseService.auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        timeout: timeout,
        forceResendingToken: forceResendingToken,
        verificationCompleted: (PhoneAuthCredential credential) {
          AppLogger.auth('SMS tự động xác thực thành công (Instant Verification)', {
            'provider': credential.providerId,
          });
          onAutoVerified(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          AppLogger.error('UserService', 'Gửi OTP thất bại: ${e.code} - ${e.message}');
          String errorMsg = 'Gửi mã OTP thất bại. Vui lòng thử lại!';
          final msg = (e.message ?? '').toUpperCase();
          if (e.code == 'quota-exceeded') {
            errorMsg = 'Hệ thống đã đạt hạn mức gửi tin nhắn hôm nay. Hãy sử dụng các số điện thoại thử nghiệm (Test Numbers)!';
          } else if (e.code == 'invalid-phone-number') {
            errorMsg = 'Số điện thoại không hợp lệ!';
          } else if (e.code == 'too-many-requests') {
            errorMsg = 'Quá nhiều yêu cầu gửi mã. Vui lòng đợi ít phút!';
          } else if (msg.contains('BILLING_NOT_ENABLED') || msg.contains('17499')) {
            errorMsg = 'Firebase yêu cầu kích hoạt thanh toán (Blaze Plan) để gửi SMS viễn thông thực tế. Vui lòng thêm số của bạn vào "Phone numbers for testing" trên Firebase Console hoặc sử dụng các số mẫu có sẵn!';
          }
          onError(errorMsg);
        },
        codeSent: (String verificationId, int? resendToken) {
          AppLogger.auth('Mã OTP đã được gửi từ Firebase', {
            'verificationId': verificationId,
            'resendToken': resendToken,
          });
          onCodeSent(verificationId, resendToken);
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          AppLogger.auth('Hết hạn tự động đọc mã OTP', {'verificationId': verificationId});
        },
      );
    } catch (e) {
      AppLogger.error('UserService', 'Ngoại lệ gửi OTP', e);
      onError('Không thể kết nối đến máy chủ xác thực.');
    }
  }

  /// Xác thực mã 6 số OTP và khởi tạo/đọc hồ sơ người dùng trên Firestore
  Future<UserModel?> verifyOtpAndSignIn({
    required String verificationId,
    required String smsCode,
    required String rawPhoneNumber,
    UserRole defaultRole = UserRole.customer,
  }) async {
    try {
      AppLogger.auth('Đang xác thực mã OTP với Firebase...', {
        'smsCode': smsCode,
        'verificationId': verificationId,
      });

      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );

      final userCredential = await FirebaseService.auth.signInWithCredential(credential);
      final user = userCredential.user;

      if (user == null) {
        throw Exception('Không tìm thấy tài khoản người dùng sau xác thực.');
      }

      final formattedPhone = formatToE164(rawPhoneNumber);
      final userDocRef = FirebaseService.firestore
          .collection(FirebaseService.colUsers)
          .doc(user.uid);

      final userDoc = await userDocRef.get();

      UserModel userModel;
      if (!userDoc.exists) {
        // Tạo người dùng mới lần đầu đăng nhập
        AppLogger.auth('Người dùng mới lần đầu đăng nhập, tạo document Firestore mới', {
          'uid': user.uid,
          'phone': formattedPhone,
          'role': defaultRole.toFirestore(),
        });
        userModel = UserModel(
          id: user.uid,
          phone: formattedPhone,
          fullName: 'Người dùng JetPost',
          role: defaultRole,
          isBanned: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await userDocRef.set(userModel.toFirestore());
      } else {
        // Đọc hồ sơ người dùng đã có
        userModel = UserModel.fromFirestore(userDoc);
        AppLogger.auth('Đã đọc hồ sơ người dùng hiện hữu từ Firestore', {
          'uid': userModel.id,
          'name': userModel.fullName,
          'role': userModel.role.toFirestore(),
        });
      }

      // Lưu phiên làm việc
      await saveUserSession(userModel);
      return userModel;
    } catch (e) {
      AppLogger.error('UserService', 'Lỗi xác thực mã OTP', e);
      rethrow;
    }
  }

  /// Chuẩn hóa số điện thoại Việt Nam sang định dạng chuẩn quốc tế E.164 (+84...)
  String formatToE164(String phone) {
    String clean = phone.replaceAll(RegExp(r'\s+|-'), '');
    if (clean.startsWith('0')) {
      return '+84${clean.substring(1)}';
    } else if (clean.startsWith('84')) {
      return '+$clean';
    } else if (clean.startsWith('+84')) {
      return clean;
    }
    return '+84$clean';
  }

  /// Kiểm tra số điện thoại có hợp lệ với các đầu số di động Việt Nam (03, 05, 07, 08, 09)
  bool isValidVietnamesePhone(String phone) {
    String clean = phone.replaceAll(RegExp(r'\s+|-'), '');
    if (clean.startsWith('+84')) {
      clean = '0${clean.substring(3)}';
    } else if (clean.startsWith('84')) {
      clean = '0${clean.substring(2)}';
    }
    final regex = RegExp(r'^(03|05|07|08|09)[0-9]{8}$');
    return regex.hasMatch(clean);
  }

  // ===========================================================================
  // 2.5. ĐỘNG CƠ XÁC THỰC EMAIL & MẬT KHẨU + MÃ OTP QUA CLOUDFLARE WORKER
  // ===========================================================================

  /// Gửi mã OTP 6 số qua Email sử dụng Cloudflare Worker Serverless (Server-Side OTP)
  Future<Map<String, dynamic>> sendEmailOtp({
    required String email,
    String type = 'REGISTER', // REGISTER | RESET_PASSWORD | CHANGE_PHONE | LINK_EMAIL
  }) async {
    try {
      AppLogger.auth('Bắt đầu gửi OTP qua Email', {'email': email, 'type': type});
      final response = await http.post(
        Uri.parse(OtpConfig.workerUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim().toLowerCase(),
          'type': type,
        }),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>? ?? {};
      if (response.statusCode == 200 && data['success'] == true) {
        AppLogger.auth('Cloudflare Worker gửi OTP qua Brevo thành công', {
          'email': email,
          'expiresAt': data['expiresAt'],
        });
        return {
          'success': true,
          'codeHash': data['codeHash'] as String? ?? '',
          'expiresAt': data['expiresAt'] as int? ?? (DateTime.now().millisecondsSinceEpoch + 5 * 60 * 1000),
          'message': data['message'] as String? ?? 'Đã gửi mã xác thực thành công!',
        };
      } else {
        final errorMsg = data['error'] as String? ?? 'Không thể gửi email OTP (Mã lỗi ${response.statusCode})';
        AppLogger.error('UserService', 'Lỗi Cloudflare Worker gửi OTP', errorMsg);
        return {'success': false, 'error': errorMsg};
      }
    } catch (e) {
      AppLogger.error('UserService', 'Ngoại lệ khi gọi Cloudflare Worker', e);
      return {'success': false, 'error': 'Lỗi kết nối tới máy chủ cấp phát OTP: $e'};
    }
  }

  /// Đối soát mã OTP 6 số do người dùng nhập với mã hash an toàn
  bool verifyEmailOtp({
    required String email,
    required String inputCode,
    required String expectedHash,
    required int expiresAt,
  }) {
    if (DateTime.now().millisecondsSinceEpoch > expiresAt) {
      AppLogger.auth('Mã OTP Email đã hết hạn hiệu lực (> 5 phút)', {'email': email});
      return false;
    }

    final cleanCode = inputCode.trim();
    final cleanEmail = email.trim().toLowerCase();
    final bytes = utf8.encode(cleanCode + cleanEmail);
    final digest = sha256.convert(bytes);
    final calculatedHash = digest.toString();

    final isMatched = calculatedHash.toLowerCase() == expectedHash.trim().toLowerCase();
    AppLogger.auth('Đối soát mã OTP Email', {
      'email': email,
      'isMatched': isMatched,
    });
    return isMatched;
  }

  /// Đăng ký tài khoản mới bằng Email & Mật khẩu
  Future<UserModel> registerWithEmailAndPassword({
    required String email,
    required String password,
    required String fullName,
    UserRole defaultRole = UserRole.customer,
  }) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      AppLogger.auth('Bắt đầu đăng ký tài khoản Email & Password', {'email': cleanEmail});

      final userCredential = await FirebaseService.auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Không tạo được tài khoản Firebase Auth.');
      }

      await user.updateDisplayName(fullName.trim());

      final userDocRef = FirebaseService.firestore
          .collection(FirebaseService.colUsers)
          .doc(user.uid);

      final userModel = UserModel(
        id: user.uid,
        phone: '',
        email: cleanEmail,
        fullName: fullName.trim(),
        role: defaultRole,
        authProviders: ['email'],
        isEmailVerified: true,
        isBanned: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await userDocRef.set(userModel.toFirestore());
      await saveUserSession(userModel);

      AppLogger.auth('Đăng ký tài khoản Email thành công', {
        'uid': user.uid,
        'email': cleanEmail,
        'role': defaultRole.toFirestore(),
      });
      return userModel;
    } on FirebaseAuthException catch (e) {
      AppLogger.error('UserService', 'Lỗi FirebaseAuth khi đăng ký: ${e.code}', e.message);
      String msg = 'Đăng ký thất bại.';
      if (e.code == 'email-already-in-use') {
        msg = 'Email này đã được sử dụng bởi một tài khoản khác.';
      } else if (e.code == 'weak-password') {
        msg = 'Mật khẩu quá yếu (tối thiểu 6 ký tự).';
      } else if (e.code == 'invalid-email') {
        msg = 'Địa chỉ email không hợp lệ.';
      }
      throw Exception(msg);
    } catch (e) {
      AppLogger.error('UserService', 'Lỗi ngoại lệ đăng ký email', e);
      rethrow;
    }
  }

  /// Đăng nhập bằng Email & Mật khẩu
  Future<UserModel> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      AppLogger.auth('Bắt đầu đăng nhập bằng Email & Password', {'email': cleanEmail});

      final userCredential = await FirebaseService.auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      final user = userCredential.user;
      if (user == null) {
        throw Exception('Không tìm thấy tài khoản người dùng.');
      }

      final userDocRef = FirebaseService.firestore
          .collection(FirebaseService.colUsers)
          .doc(user.uid);

      final userDoc = await userDocRef.get();

      UserModel userModel;
      if (!userDoc.exists) {
        final role = cleanEmail.contains('admin')
            ? UserRole.admin
            : (cleanEmail.contains('tai') || cleanEmail.contains('driver')
                ? UserRole.driver
                : UserRole.customer);

        userModel = UserModel(
          id: user.uid,
          phone: '',
          email: cleanEmail,
          fullName: user.displayName ?? (role == UserRole.admin ? 'Quản Trị Viên' : 'Người dùng'),
          role: role,
          authProviders: ['email'],
          isEmailVerified: user.emailVerified,
          isBanned: false,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await userDocRef.set(userModel.toFirestore());
      } else {
        userModel = UserModel.fromFirestore(userDoc);
      }

      if (userModel.isBanned) {
        await clearUserSession();
        throw Exception('Tài khoản của bạn đã bị khóa do vi phạm chính sách hệ thống.');
      }

      await saveUserSession(userModel);
      AppLogger.auth('Đăng nhập Email thành công', {
        'uid': userModel.id,
        'email': cleanEmail,
        'role': userModel.role.toFirestore(),
      });
      return userModel;
    } on FirebaseAuthException catch (e) {
      AppLogger.error('UserService', 'Lỗi FirebaseAuth khi đăng nhập: ${e.code}', e.message);
      String msg = 'Đăng nhập thất bại.';
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        msg = 'Email hoặc mật khẩu không chính xác.';
      } else if (e.code == 'user-disabled') {
        msg = 'Tài khoản này đã bị vô hiệu hóa.';
      } else if (e.code == 'too-many-requests') {
        msg = 'Quá nhiều lần thử thất bại. Vui lòng đợi trong giây lát.';
      }
      throw Exception(msg);
    } catch (e) {
      AppLogger.error('UserService', 'Ngoại lệ đăng nhập email', e);
      rethrow;
    }
  }

  /// Liên kết Email & Mật khẩu vào tài khoản hiện tại (Account Linking)
  Future<bool> linkEmailToCurrentAccount({
    required String email,
    required String password,
  }) async {
    final user = FirebaseService.currentUser;
    if (user == null) return false;

    try {
      final cleanEmail = email.trim().toLowerCase();
      AppLogger.auth('Bắt đầu liên kết Email vào tài khoản hiện tại', {
        'uid': user.uid,
        'email': cleanEmail,
      });

      final credential = EmailAuthProvider.credential(
        email: cleanEmail,
        password: password,
      );

      await user.linkWithCredential(credential);

      await FirebaseService.firestore
          .collection(FirebaseService.colUsers)
          .doc(user.uid)
          .update({
        'email': cleanEmail,
        'isEmailVerified': true,
        'authProviders': FieldValue.arrayUnion(['email']),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      AppLogger.auth('Liên kết Email thành công', {'uid': user.uid, 'email': cleanEmail});
      return true;
    } on FirebaseAuthException catch (e) {
      AppLogger.error('UserService', 'Lỗi link email: ${e.code}', e.message);
      String msg = 'Liên kết Email thất bại.';
      if (e.code == 'email-already-in-use') {
        msg = 'Email này đã được dùng cho tài khoản khác.';
      } else if (e.code == 'credential-already-in-use') {
        msg = 'Thông tin xác thực đã được liên kết với một tài khoản khác.';
      }
      throw Exception(msg);
    } catch (e) {
      AppLogger.error('UserService', 'Lỗi liên kết email', e);
      rethrow;
    }
  }

  /// Đổi mật khẩu cho tài khoản hiện tại (Xác thực lại bằng mật khẩu cũ)
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = FirebaseService.auth.currentUser;
    if (user == null || user.email == null) {
      throw Exception('Tài khoản hiện tại chưa có thông tin Email để đổi mật khẩu.');
    }

    try {
      AppLogger.auth('Bắt đầu quy trình đổi mật khẩu', {'email': user.email});

      // 1. Xác thực lại với mật khẩu cũ
      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);

      // 2. Cập nhật mật khẩu mới
      await user.updatePassword(newPassword);

      // 3. Cập nhật updatedAt trong Firestore users
      await FirebaseService.firestore
          .collection(FirebaseService.colUsers)
          .doc(user.uid)
          .update({'updatedAt': Timestamp.now()});

      AppLogger.auth('Đổi mật khẩu thành công', {'uid': user.uid});
    } on FirebaseAuthException catch (e) {
      AppLogger.error('UserService', 'Lỗi đổi mật khẩu: ${e.code}', e.message);
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw Exception('Mật khẩu hiện tại không chính xác.');
      } else if (e.code == 'weak-password') {
        throw Exception('Mật khẩu mới quá yếu. Vui lòng nhập tối thiểu 6 ký tự.');
      } else if (e.code == 'requires-recent-login') {
        throw Exception('Phiên làm việc đã hết hạn. Vui lòng đăng nhập lại trước khi đổi mật khẩu.');
      } else {
        throw Exception(e.message ?? 'Đổi mật khẩu thất bại.');
      }
    } catch (e) {
      AppLogger.error('UserService', 'Ngoại lệ đổi mật khẩu', e);
      throw Exception(e.toString().replaceAll('Exception: ', ''));
    }
  }

  /// Liên kết Số điện thoại vào tài khoản hiện tại (Account Linking)
  Future<bool> linkPhoneToCurrentAccount({
    required String verificationId,
    required String smsCode,
    required String rawPhone,
  }) async {
    final user = FirebaseService.currentUser;
    if (user == null) return false;

    try {
      final formattedPhone = formatToE164(rawPhone);
      AppLogger.auth('Bắt đầu liên kết SĐT vào tài khoản hiện tại', {
        'uid': user.uid,
        'phone': formattedPhone,
      });

      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode.trim(),
      );

      // Nếu tài khoản đã có SĐT (providerId: 'phone') -> dùng updatePhoneNumber() để đổi số.
      // Nếu là tài khoản Email thuần túy chưa có SĐT -> dùng linkWithCredential() để liên kết lần đầu.
      final hasPhoneProvider = user.providerData.any((p) => p.providerId == 'phone');
      if (hasPhoneProvider) {
        await user.updatePhoneNumber(credential);
      } else {
        try {
          await user.linkWithCredential(credential);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'provider-already-linked') {
            await user.updatePhoneNumber(credential);
          } else {
            rethrow;
          }
        }
      }

      await FirebaseService.firestore
          .collection(FirebaseService.colUsers)
          .doc(user.uid)
          .update({
        'phone': formattedPhone,
        'authProviders': FieldValue.arrayUnion(['phone']),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyUserPhone, formattedPhone);

      AppLogger.auth('Liên kết/Đổi SĐT thành công', {'uid': user.uid, 'phone': formattedPhone});
      return true;
    } on FirebaseAuthException catch (e) {
      AppLogger.error('UserService', 'Lỗi liên kết/đổi SĐT: ${e.code}', e.message);
      String msg = 'Cập nhật số điện thoại thất bại.';
      if (e.code == 'credential-already-in-use') {
        msg = 'Số điện thoại này đã được liên kết với một tài khoản khác.';
      } else if (e.code == 'invalid-verification-code') {
        msg = 'Mã OTP không chính xác. Vui lòng kiểm tra lại.';
      } else if (e.code == 'session-expired') {
        msg = 'Mã OTP đã hết hạn. Vui lòng gửi lại mã mới.';
      } else {
        msg = e.message ?? msg;
      }
      throw Exception(msg);
    } catch (e) {
      AppLogger.error('UserService', 'Lỗi liên kết SĐT', e);
      rethrow;
    }
  }

  /// Kiểm tra tiền trạm xem Số điện thoại đã được đăng ký bởi tài khoản nào chưa
  Future<bool> isPhoneAlreadyRegistered(String rawOrFormattedPhone, {String? excludeUid}) async {
    try {
      final formattedPhone = formatToE164(rawOrFormattedPhone);
      final query = await FirebaseService.firestore
          .collection(FirebaseService.colUsers)
          .where('phone', isEqualTo: formattedPhone)
          .limit(2)
          .get();

      if (query.docs.isEmpty) return false;

      if (excludeUid != null) {
        return query.docs.any((d) => d.id != excludeUid);
      }
      return true;
    } catch (e) {
      AppLogger.error('UserService', 'Lỗi kiểm tra trùng SĐT', e);
      return false;
    }
  }

  /// Kiểm tra tiền trạm xem Biển số xe đã được đăng ký trong hệ thống đối tác chưa
  Future<bool> isPlateAlreadyRegistered(String plateNumber, {String? excludeDriverId}) async {
    try {
      final cleanPlate = plateNumber.trim().toUpperCase();
      final query = await FirebaseService.firestore
          .collection(FirebaseService.colDrivers)
          .where('plateNumber', isEqualTo: cleanPlate)
          .limit(2)
          .get();

      if (query.docs.isEmpty) return false;

      if (excludeDriverId != null) {
        return query.docs.any((d) => d.id != excludeDriverId);
      }
      return true;
    } catch (e) {
      AppLogger.error('UserService', 'Lỗi kiểm tra trùng Biển số xe', e);
      return false;
    }
  }

  /// Kiểm tra tiền trạm xem Email đã được đăng ký bởi tài khoản nào chưa
  Future<bool> isEmailAlreadyRegistered(String email, {String? excludeUid}) async {
    try {
      final cleanEmail = email.trim().toLowerCase();
      final query = await FirebaseService.firestore
          .collection(FirebaseService.colUsers)
          .where('email', isEqualTo: cleanEmail)
          .limit(2)
          .get();

      if (query.docs.isEmpty) return false;

      if (excludeUid != null) {
        return query.docs.any((d) => d.id != excludeUid);
      }
      return true;
    } catch (e) {
      AppLogger.error('UserService', 'Lỗi kiểm tra trùng Email', e);
      return false;
    }
  }

  // ===========================================================================
  // 3. QUẢN LÝ HỒ SƠ CÁ NHÂN (USER PROFILE)
  // ===========================================================================

  /// Lấy thông tin hồ sơ của người dùng hiện tại
  Future<UserModel?> getCurrentUserProfile() async {
    final uid = FirebaseService.currentUserId;
    if (uid == null) return null;

    try {
      final doc = await FirebaseService.firestore
          .collection(FirebaseService.colUsers)
          .doc(uid)
          .get();

      if (!doc.exists) return null;
      return UserModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('[UserService] Lỗi đọc profile: $e');
      return null;
    }
  }

  /// Cập nhật Họ và Tên hoặc Ảnh đại diện
  Future<bool> updateUserProfile({String? fullName, String? avatarUrl}) async {
    final uid = FirebaseService.currentUserId;
    if (uid == null) return false;

    try {
      AppLogger.userAction('Profile', 'Cập nhật thông tin tài khoản', {
        'fullName': fullName,
        'hasAvatar': avatarUrl != null,
      });

      final updates = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (fullName != null && fullName.trim().isNotEmpty) {
        updates['fullName'] = fullName.trim();
      }
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        updates['avatarUrl'] = avatarUrl;
      }

      await FirebaseService.firestore
          .collection(FirebaseService.colUsers)
          .doc(uid)
          .update(updates);

      // Cập nhật lại SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      if (fullName != null) {
        await prefs.setString(_prefKeyUserName, fullName.trim());
      }

      AppLogger.info('UserService', 'Cập nhật Profile thành công cho UID: $uid');
      return true;
    } catch (e) {
      AppLogger.error('UserService', 'Lỗi cập nhật profile', e);
      return false;
    }
  }

  /// Cập nhật số điện thoại người dùng sau khi xác thực OTP thành công (Task 3.4)
  Future<bool> updateUserPhone(String newPhone) async {
    final uid = FirebaseService.currentUserId;
    if (uid == null) return false;

    try {
      final formatted = formatToE164(newPhone);
      await FirebaseService.firestore
          .collection(FirebaseService.colUsers)
          .doc(uid)
          .update({
        'phone': formatted,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyUserPhone, formatted);

      AppLogger.auth('Đổi số điện thoại thành công', {'uid': uid, 'newPhone': formatted});
      return true;
    } catch (e) {
      AppLogger.error('UserService', 'Lỗi cập nhật số điện thoại', e);
      return false;
    }
  }

  // ===========================================================================
  // 4. QUY TRÌNH ĐỊNH DANH ĐIỆN TỬ eKYC CHO TÀI XẾ
  // ===========================================================================

  /// Nộp hồ sơ đăng ký Đối tác Tài xế lên Cloud Firestore (Task 3.3)
  Future<bool> submitDriverKyc({
    required String vehicleType,
    required String plateNumber,
    required String idCardFrontUrl,
    required String idCardBackUrl,
    required String licenseUrl,
  }) async {
    final uid = FirebaseService.currentUserId;
    if (uid == null) return false;

    try {
      AppLogger.ekyc('Nộp hồ sơ', 'Bắt đầu ghi dữ liệu lên Firestore', 'Xe: $vehicleType, Biển số: $plateNumber');

      final driverDocRef = FirebaseService.firestore
          .collection(FirebaseService.colDrivers)
          .doc(uid);

      final now = DateTime.now();

      final driverModel = DriverModel(
        id: uid,
        vehicleType: vehicleType,
        plateNumber: plateNumber.trim().toUpperCase(),
        idCardFrontUrl: idCardFrontUrl,
        idCardBackUrl: idCardBackUrl,
        licenseUrl: licenseUrl,
        status: DriverApprovalStatus.pendingApproval,
        isOnline: false,
        isBusy: false,
        rating: 5.0,
        totalReviews: 0,
        totalTrips: 0,
        walletBalance: 0.0,
        lastActiveAt: now,
      );

      await driverDocRef.set(driverModel.toFirestore());

      // BẢO MẬT HỆ THỐNG (RBAC Guard):
      // Khi nộp hồ sơ eKYC, tài khoản người dùng vẫn giữ nguyên vai trò 'customer' trong users/{uid}.
      // Hồ sơ đối tác được lưu trong collection `drivers` ở trạng thái `pendingApproval`.
      // Chỉ khi Admin thẩm định CCCD/GPLX và bấm "Phê duyệt" (Task 4.3), tài khoản mới được kích hoạt làm tài xế.

      AppLogger.ekyc('Nộp hồ sơ', 'HOÀN TẤT', 'UID: $uid đã nộp hồ sơ đối tác tài xế, trạng thái pendingApproval');
      return true;
    } catch (e) {
      AppLogger.error('UserService', 'Lỗi gửi hồ sơ eKYC', e);
      return false;
    }
  }

  /// Tra cứu hồ sơ đối tác tài xế
  Future<DriverModel?> getDriverProfile(String driverId) async {
    try {
      final doc = await FirebaseService.firestore
          .collection(FirebaseService.colDrivers)
          .doc(driverId)
          .get();

      if (!doc.exists) return null;
      return DriverModel.fromFirestore(doc);
    } catch (e) {
      debugPrint('[UserService] Lỗi đọc hồ sơ tài xế: $e');
      return null;
    }
  }

  // ===========================================================================
  // 5. TRUNG TÂM NHẮN TIN TRỰC TIẾP ĐA NGƯỜI DÙNG P2P (DIRECT USER CHAT)
  // ===========================================================================

  /// Lắng nghe luồng hội thoại thời gian thực của người dùng hiện tại
  Stream<List<ConversationModel>> getConversationsStream() {
    final uid = FirebaseService.currentUserId;
    if (uid == null) return const Stream.empty();

    return FirebaseService.firestore
        .collection(FirebaseService.colConversations)
        .where('participants', arrayContains: uid)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ConversationModel.fromFirestore(doc))
          .toList();
      // Sắp xếp thời gian mới nhất lên đầu trong bộ nhớ để không yêu cầu tạo composite index trên Firestore
      list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return list;
    });
  }

  /// Lắng nghe danh sách tin nhắn thời gian thực trong 1 phòng chat
  Stream<List<MessageModel>> getMessagesStream(String chatId) {
    return FirebaseService.firestore
        .collection(FirebaseService.colConversations)
        .doc(chatId)
        .collection(FirebaseService.subMessages)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => MessageModel.fromFirestore(doc, chatId))
          .toList();
    });
  }

  /// Tạo hoặc lấy mã phòng chat duy nhất theo chuẩn alphabet (O(1))
  Future<String> getOrCreateConversation({
    required String targetUserId,
    required String targetName,
    String? targetAvatar,
  }) async {
    final myUid = FirebaseService.currentUserId;
    if (myUid == null) throw Exception('Người dùng chưa đăng nhập');

    final chatId = ConversationModel.generateId(myUid, targetUserId);
    final convRef = FirebaseService.firestore
        .collection(FirebaseService.colConversations)
        .doc(chatId);

    final convDoc = await convRef.get();
    if (!convDoc.exists) {
      // Đọc thông tin của chính mình
      final myProfile = await getCurrentUserProfile();
      final myName = myProfile?.fullName ?? 'Người dùng';
      final myAvatar = myProfile?.avatarUrl;

      final newConv = ConversationModel(
        id: chatId,
        participants: [myUid, targetUserId],
        participantDetails: {
          myUid: {
            'name': myName,
            'avatar': myAvatar,
          },
          targetUserId: {
            'name': targetName,
            'avatar': targetAvatar,
          },
        },
        lastMessage: 'Đã bắt đầu cuộc trò chuyện',
        lastSenderId: myUid,
        unreadCount: {
          myUid: 0,
          targetUserId: 0,
        },
        updatedAt: DateTime.now(),
      );

      await convRef.set(newConv.toFirestore());
    }

    return chatId;
  }

  /// Gửi tin nhắn mới vào phòng chat 1-1
  Future<void> sendMessage({
    required String chatId,
    required String receiverId,
    required String content,
  }) async {
    final senderId = FirebaseService.currentUserId;
    if (senderId == null || content.trim().isEmpty) return;

    final trimmed = content.trim();
    final now = DateTime.now();

    final convRef = FirebaseService.firestore
        .collection(FirebaseService.colConversations)
        .doc(chatId);

    // 1. Ghi tin nhắn vào sub-collection `messages`
    final msgDocRef = convRef.collection(FirebaseService.subMessages).doc();
    final message = MessageModel(
      id: msgDocRef.id,
      conversationId: chatId,
      senderId: senderId,
      receiverId: receiverId,
      content: trimmed,
      isRead: false,
      timestamp: now,
    );

    await msgDocRef.set(message.toFirestore());

    // 2. Cập nhật bản ghi cha `conversations`
    await convRef.update({
      'lastMessage': trimmed,
      'lastSenderId': senderId,
      'updatedAt': Timestamp.fromDate(now),
      'unreadCount.$receiverId': FieldValue.increment(1),
    });

    AppLogger.chat('Gửi tin nhắn P2P thành công', {
      'chatId': chatId,
      'to': receiverId,
      'length': trimmed.length,
      'content': trimmed.length > 25 ? '${trimmed.substring(0, 25)}...' : trimmed,
    });
  }

  /// Đánh dấu đã đọc toàn bộ tin nhắn trong phòng chat
  Future<void> markConversationAsRead(String chatId) async {
    final myUid = FirebaseService.currentUserId;
    if (myUid == null) return;

    try {
      await FirebaseService.firestore
          .collection(FirebaseService.colConversations)
          .doc(chatId)
          .update({
        'unreadCount.$myUid': 0,
      });
      AppLogger.chat('Đã đánh dấu đã đọc cuộc hội thoại', {'chatId': chatId});
    } catch (e) {
      AppLogger.error('UserService', 'Lỗi đánh dấu đã đọc', e);
    }
  }
}

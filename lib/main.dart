import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'modules/user/screens/welcome_gate_screen.dart';
import 'routes/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Firebase App với cấu hình đa nền tảng
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const JetPostApp());
}

/// Ứng dụng Hợp nhất JetPost (Single All-in-One Multi-Role Flutter App)
class JetPostApp extends StatelessWidget {
  const JetPostApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JetPost',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Tự động đổi Sáng/Tối theo hệ điều hành hoặc tài xế ban đêm
      initialRoute: AppRoutes.welcomeGate,
      routes: {
        AppRoutes.welcomeGate: (context) => const WelcomeGateScreen(),
      },
      onUnknownRoute: AppRoutes.onUnknownRoute,
    );
  }
}

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';
import 'routes/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Khởi tạo Firebase App với cấu hình đa nền tảng
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Khởi tạo cấu hình Theme Mode từ SharedPreferences
  await AppTheme.init();

  runApp(const JetPostApp());
}

/// Ứng dụng Hợp nhất JetPost (Single All-in-One Multi-Role Flutter App)
class JetPostApp extends StatelessWidget {
  const JetPostApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeModeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'JetPost',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          initialRoute: AppRoutes.welcomeGate,
          routes: AppRoutes.routes,
          onGenerateRoute: AppRoutes.onGenerateRoute,
          onUnknownRoute: AppRoutes.onUnknownRoute,
        );
      },
    );
  }
}

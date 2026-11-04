import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import 'phone_auth_screen.dart';

class LoginScreen extends StatelessWidget {
  final UserRole targetRole;

  const LoginScreen({super.key, this.targetRole = UserRole.customer});

  void _openLogin(BuildContext context, AuthFlow flow) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PhoneAuthScreen(targetRole: targetRole, flow: flow),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Đăng nhập')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 12),
            const Text(
              'Chọn cách đăng nhập',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Đăng nhập để tiếp tục sử dụng JetPost.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            _LoginMethodCard(
              icon: Icons.lock_outline,
              title: 'Đăng nhập bằng Tài Khoản',
              description:
                  'Đăng nhập bằng tài khoản Gmail và mật khẩu của bạn.',
              onTap: () => _openLogin(context, AuthFlow.emailLogin),
            ),
            const SizedBox(height: 14),
            _LoginMethodCard(
              icon: Icons.phone_android,
              title: 'Đăng nhập bằng SĐT',
              description: 'Mã OTP sẽ được gửi đến số điện thoại của bạn.',
              onTap: () => _openLogin(context, AuthFlow.phoneLogin),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginMethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _LoginMethodCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: AppColors.primary, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

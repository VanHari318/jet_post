import 'package:flutter/material.dart';
import '../../../core/constants/app_enums.dart';
import 'phone_auth_screen.dart';

class RegistrationScreen extends StatelessWidget {
  final UserRole targetRole;

  const RegistrationScreen({super.key, this.targetRole = UserRole.customer});

  @override
  Widget build(BuildContext context) {
    return PhoneAuthScreen(targetRole: targetRole, flow: AuthFlow.register);
  }
}

import 'package:flutter/material.dart';

import '../widgets/role_welcome_layout.dart';

class AdminWelcomeScreen extends StatelessWidget {
  const AdminWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => RoleWelcomeLayout(
    role: WelcomeRole.admin,
    onContinue: () {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Admin Dashboard is not available in Sprint 1–8 yet.'),
        ),
      );
    },
  );
}

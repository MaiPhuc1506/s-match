import 'package:flutter/material.dart';

import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../widgets/role_welcome_layout.dart';

class AdminWelcomeScreen extends StatelessWidget {
  const AdminWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => RoleWelcomeLayout(
    role: WelcomeRole.admin,
    onContinue: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const DashboardScreen(role: DashboardRole.admin),
        ),
      );
    },
  );
}

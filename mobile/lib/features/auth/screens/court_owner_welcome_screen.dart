import 'package:flutter/material.dart';

import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../widgets/role_welcome_layout.dart';

class CourtOwnerWelcomeScreen extends StatelessWidget {
  const CourtOwnerWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => RoleWelcomeLayout(
    role: WelcomeRole.courtOwner,
    onContinue: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              const DashboardScreen(role: DashboardRole.owner),
        ),
      );
    },
  );
}

import 'package:flutter/material.dart';

import '../widgets/role_welcome_layout.dart';

class AdminWelcomeScreen extends StatelessWidget {
  const AdminWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => RoleWelcomeLayout(
    role: WelcomeRole.admin,
    onContinue: () {
      // The existing project does not yet have an Admin Dashboard destination.
    },
  );
}

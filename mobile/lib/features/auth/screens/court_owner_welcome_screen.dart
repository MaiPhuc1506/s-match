import 'package:flutter/material.dart';

import '../../facility/screens/facility_list_screen.dart';
import '../widgets/role_welcome_layout.dart';

class CourtOwnerWelcomeScreen extends StatelessWidget {
  const CourtOwnerWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => RoleWelcomeLayout(
    role: WelcomeRole.courtOwner,
    onContinue: () {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const FacilityListScreen()),
      );
    },
  );
}

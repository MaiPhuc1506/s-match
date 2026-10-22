import 'package:flutter/material.dart';

import '../widgets/role_welcome_layout.dart';
import 'player_profile_screen.dart';

class PlayerWelcomeScreen extends StatelessWidget {
  const PlayerWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => RoleWelcomeLayout(
    role: WelcomeRole.player,
    onContinue: () {
      Navigator.of(context).push(
        PageRouteBuilder(
          settings: const RouteSettings(name: '/player-profile'),
          transitionDuration: const Duration(milliseconds: 250),
          pageBuilder: (context, animation, secondaryAnimation) =>
              const PlayerProfileScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(
                opacity: CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                ),
                child: child,
              ),
        ),
      );
    },
  );
}

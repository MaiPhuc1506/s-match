import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../services/auth_service.dart';
import '../services/player_profile_service.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/playing_area_picker.dart';
import 'player_welcome_screen.dart';

/// First Google sign-in only: capture profile information using
/// the existing auth form styling. Never touches GPS/location consent.
class GoogleOnboardingScreen extends StatefulWidget {
  const GoogleOnboardingScreen({super.key, this.initialName});

  final String? initialName;

  @override
  State<GoogleOnboardingScreen> createState() => _GoogleOnboardingScreenState();
}

class _GoogleOnboardingScreenState extends State<GoogleOnboardingScreen> {
  late final TextEditingController _nameController;
  final _areaController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text:
          widget.initialName ??
          AuthService.instance.currentUser?['fullName'] as String? ??
          '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();
    final name = _nameController.text.trim();
    final area = _areaController.text.trim();
    if (name.isEmpty) {
      _show('Please enter your display name.');
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await PlayerProfileService.instance.updateMyProfile(
        fullName: name,
        playingArea: area.isEmpty ? null : area,
        completeGoogleOnboarding: true,
      );
      if (!mounted) return;
      final user = AuthService.instance.currentUser;
      if (user != null) {
        AuthService.instance.currentUser = {
          ...user,
          'fullName': saved.fullName,
        };
      }
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const PlayerWelcomeScreen()),
      );
    } on PlayerProfileException catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      _show(error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      _show('Could not save your profile. Please try again.');
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Complete your profile', style: AppTextStyles.titleBold),
              const SizedBox(height: 12),
              Text(
                'Add your name and optionally your usual playing area.',
                style: AppTextStyles.inputPlaceholder,
              ),
              const SizedBox(height: 24),
              CustomTextField(
                controller: _nameController,
                hintText: 'Display Name',
                prefixIcon: Icons.person_outline,
                height: 56,
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _saving
                    ? null
                    : () async {
                        final selected = await pickPlayingArea(
                          context,
                          _areaController.text,
                        );
                        if (mounted && selected != null) {
                          setState(() => _areaController.text = selected);
                        }
                      },
                child: AbsorbPointer(
                  child: CustomTextField(
                    controller: _areaController,
                    hintText: 'Usual Playing Area (optional)',
                    prefixIcon: Icons.location_city_outlined,
                    height: 56,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _saving ? null : _continue,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.white,
                          ),
                        )
                      : Text('Continue', style: AppTextStyles.buttonPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

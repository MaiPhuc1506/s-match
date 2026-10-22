import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/sprint2_presentation.dart';
import '../../../core/network/api_client.dart';
import '../services/auth_service.dart';
import '../services/player_profile_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, this.initialProfile});
  final OwnPlayerProfile? initialProfile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const Color _background = Color(0xFFF7F8F5);
  static const Color _primary = Color(0xFF05644F);
  static const Color _textPrimary = Color(0xFF142824);
  static const Color _textSecondary = Color(0xFF64716D);

  final TextEditingController _nameController = TextEditingController(
    text: 'Phúc Mai',
  );

  final TextEditingController _bioController = TextEditingController(
    text: 'Badminton enthusiast. Always ready for a friendly match and improving together.',
  );

  final TextEditingController _locationController = TextEditingController(
    text: 'Da Nang, Vietnam',
  );

  String _dominantHand = 'Right';
  String _preferredMode = 'Doubles';

  bool _isSaving = false;
  bool _isLoadingProfile = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialProfile;
    if (initial != null) {
      _nameController.text = initial.fullName;
      _bioController.text = initial.bio;
    } else if (ApiClient.instance.token != null) {
      _nameController.text =
          AuthService.instance.currentUser?['fullName'] as String? ?? '';
      _bioController.clear();
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoadingProfile = true;
      _loadError = null;
    });
    try {
      final profile = await PlayerProfileService.instance.getMyProfile();
      if (!mounted) return;
      setState(() {
        _nameController.text = profile.fullName;
        _bioController.text = profile.bio;
        _isLoadingProfile = false;
      });
    } on PlayerProfileException catch (error) {
      if (mounted) {
        setState(() {
          _isLoadingProfile = false;
          _loadError = error.message;
        });
      }
    }
  }

  Future<void> _saveChanges() async {
    if (_isSaving || _isLoadingProfile || _loadError != null) return;
    FocusScope.of(context).unfocus();
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Vui lòng nhập họ và tên.')));
      return;
    }
    if (_bioController.text.characters.length > 150) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bio chỉ được tối đa 150 ký tự.')),
      );
      return;
    }
    final localOnlyChanges =
        _locationController.text != 'Da Nang, Vietnam' ||
        _dominantHand != 'Right' ||
        _preferredMode != 'Doubles';
    setState(() => _isSaving = true);
    try {
      final saved = await PlayerProfileService.instance.updateMyProfile(
        fullName: _nameController.text,
        bio: _bioController.text,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(saved);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            localOnlyChanges
                ? 'Đã lưu tên và Bio. Vị trí, tay thuận và chế độ chơi chưa được API hỗ trợ lưu.'
                : 'Đã cập nhật hồ sơ thành công.',
          ),
        ),
      );
    } on PlayerProfileException catch (error) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  TextStyle _textStyle({
    required double size,
    required FontWeight weight,
    required double lineHeight,
    Color color = _textPrimary,
  }) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      height: lineHeight / size,
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: Scaffold(
      backgroundColor: _background,
      resizeToAvoidBottomInset: true,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 393),
          child: Column(
            children: [
              const Sprint2BackHeader(title: 'Edit Profile'),
              if (_isLoadingProfile)
                const LinearProgressIndicator(minHeight: 2, color: _primary),
              if (_loadError != null)
                MaterialBanner(
                  content: Text(_loadError!),
                  actions: [
                    TextButton(
                      onPressed: _loadProfile,
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              Expanded(
                child: AbsorbPointer(
                  absorbing: _isSaving || _isLoadingProfile,
                  child: Sprint2FormBody(
                    button: _buildSaveButton(),
                    children: [
                      _buildAvatarSection(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Basic Information',
                            style: _textStyle(
                              size: 16,
                              weight: FontWeight.w600,
                              lineHeight: 22,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildFullNameField(),
                          const SizedBox(height: 8),
                          _buildLocationField(),
                          const SizedBox(height: 8),
                          _buildBioField(),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Playing Preferences',
                            style: _textStyle(
                              size: 16,
                              weight: FontWeight.w600,
                              lineHeight: 22,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildDominantHandSection(),
                          const SizedBox(height: 10),
                          _buildPreferredModeSection(),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildAvatarSection() => GestureDetector(
    onTap: () {
      // Sau này mở image picker tại đây.
    },
    child: SizedBox(
      height: 140,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            const Positioned.fill(child: Sprint2CourtPhoto(opacity: .3)),
            Positioned(
              top: 18,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 104,
                  height: 104,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/sprint2_edit_Avatar.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left:
                  (MediaQuery.sizeOf(context).width.clamp(0, 393).toDouble() -
                          48) /
                      2 +
                  32.5,
              top: 91,
              child: const Sprint2CameraBadge(),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildFullNameField() => _inlineField(
    'Full Name',
    _nameController,
    'assets/icons/register_user.svg',
  );
  Widget _buildLocationField() => _inlineField(
    'Location',
    _locationController,
    'assets/icons/sprint2_edit_Sprint3IconLocation.svg',
  );

  Widget _inlineField(
    String label,
    TextEditingController controller,
    String asset,
  ) => SizedBox(
    height: 44,
    child: TextField(
      controller: controller,
      textAlign: TextAlign.right,
      style: _textStyle(size: 14, weight: FontWeight.w400, lineHeight: 20),
      decoration: InputDecoration(
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        prefixIconConstraints: const BoxConstraints(maxWidth: 145),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Center(
                  child: SvgPicture.asset(
                    asset,
                    width: asset.contains('Location') ? 20 : 16,
                    height: asset.contains('Location') ? 20 : 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: _textStyle(
                  size: 14,
                  weight: FontWeight.w400,
                  lineHeight: 20,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ),
        contentPadding: const EdgeInsets.fromLTRB(0, 12, 16, 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF087A61), width: 1.5),
        ),
      ),
    ),
  );

  Widget _buildBioField() => Container(
    height: 138,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Bio',
          style: _textStyle(
            size: 14,
            weight: FontWeight.w400,
            lineHeight: 20,
            color: _textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 96,
          child: Stack(
            children: [
              TextField(
                controller: _bioController,
                maxLength: 150,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                style: _textStyle(
                  size: 14,
                  weight: FontWeight.w400,
                  lineHeight: 20,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  isDense: true,
                  contentPadding: const EdgeInsets.fromLTRB(10, 8, 10, 24),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFFE8ECE9),
                      width: .6,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFF087A61),
                      width: 1.5,
                    ),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              Positioned(
                right: 10,
                bottom: 8,
                child: Text(
                  '${_bioController.text.length}/150',
                  style: _textStyle(
                    size: 11,
                    weight: FontWeight.w400,
                    lineHeight: 16,
                    color: const Color(0xFF87918C),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _buildDominantHandSection() {
    return SizedBox(
      width: 345,
      height: 62,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dominant Hand',
            style: _textStyle(
              size: 14,
              weight: FontWeight.w500,
              lineHeight: 19,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildChoice(
                  label: 'Left',
                  selected: _dominantHand == 'Left',
                  onTap: () => setState(() => _dominantHand = 'Left'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildChoice(
                  label: 'Right',
                  selected: _dominantHand == 'Right',
                  onTap: () => setState(() => _dominantHand = 'Right'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreferredModeSection() {
    return SizedBox(
      width: 345,
      height: 62,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preferred Mode',
            style: _textStyle(
              size: 14,
              weight: FontWeight.w500,
              lineHeight: 19,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _buildChoice(
                  label: 'Singles',
                  selected: _preferredMode == 'Singles',
                  onTap: () => setState(() => _preferredMode = 'Singles'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildChoice(
                  label: 'Doubles',
                  selected: _preferredMode == 'Doubles',
                  onTap: () => setState(() => _preferredMode = 'Doubles'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildChoice(
                  label: 'Both',
                  selected: _preferredMode == 'Both',
                  onTap: () => setState(() => _preferredMode = 'Both'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChoice({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _primary : const Color(0xFFF3F6F3),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: _textStyle(
            size: 13,
            weight: FontWeight.w500,
            lineHeight: 18,
            color: selected ? Colors.white : _textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: 345,
      height: 52,
      child: ElevatedButton(
        onPressed: _isSaving || _isLoadingProfile || _loadError != null
            ? null
            : _saveChanges,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          padding: EdgeInsets.zero,
        ),
        child: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                'Save Changes',
                style: _textStyle(
                  size: 15,
                  weight: FontWeight.w600,
                  lineHeight: 20,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

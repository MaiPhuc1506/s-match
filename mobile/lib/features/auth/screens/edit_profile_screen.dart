import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const Color _background = Color(0xFFF7F8F5);
  static const Color _primary = Color(0xFF05644F);
  static const Color _textPrimary = Color(0xFF1C1C1C);
  static const Color _textSecondary = Color(0xFF6B6B6B);
  static const Color _border = Color(0xFFC6D2CC);

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
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: _background,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _background,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 393),
              child: Column(
                children: [
                  _buildAppBar(),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                      child: Column(
                        children: [
                          _buildAvatarSection(),
                          const SizedBox(height: 10),
                          _buildFullNameField(),
                          const SizedBox(height: 10),
                          _buildBioField(),
                          const SizedBox(height: 10),
                          _buildLocationField(),
                          const SizedBox(height: 10),
                          _buildDominantHandSection(),
                          const SizedBox(height: 10),
                          _buildPreferredModeSection(),
                          const SizedBox(height: 10),
                          _buildSaveButton(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SizedBox(
      width: 393,
      height: 96,
      child: Column(
        children: [
          const SizedBox(height: 40),
          SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/icons/back_chevron.svg',
                          width: 24,
                          height: 24,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Edit Profile',
                      textAlign: TextAlign.center,
                      style: _textStyle(
                        size: 22,
                        weight: FontWeight.w700,
                        lineHeight: 30,
                      ),
                    ),
                  ),
                  const SizedBox(width: 44, height: 44),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarSection() {
    return SizedBox(
      width: 345,
      height: 132,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -75,
            top: 38,
            child: SvgPicture.asset(
              'assets/icons/edit_profile_wave_left.svg',
              width: 230,
              height: 70,
              fit: BoxFit.fill,
            ),
          ),
          Positioned(
            left: 188,
            top: 28,
            child: SvgPicture.asset(
              'assets/icons/edit_profile_wave_right.svg',
              width: 230,
              height: 70,
              fit: BoxFit.fill,
            ),
          ),
          Positioned(
            left: 120.5,
            top: 0,
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 4),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x24000000),
                    offset: Offset(0, 4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/profile_avatar.png',
                  width: 104,
                  height: 104,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                ),
              ),
            ),
          ),
          Positioned(
            left: 198,
            top: 72,
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _primary,
                shape: BoxShape.circle,
                border: Border.all(color: _background, width: 3),
              ),
              child: SvgPicture.asset(
                'assets/icons/profile_camera.svg',
                width: 18,
                height: 18,
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 110,
            child: GestureDetector(
              onTap: () {
                // Sau này mở image picker tại đây.
              },
              child: Text(
                'Change Photo',
                textAlign: TextAlign.center,
                style: _textStyle(
                  size: 15,
                  weight: FontWeight.w600,
                  lineHeight: 21,
                  color: const Color(0xFF054D3F),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullNameField() {
    return _LabeledSection(
      height: 80,
      label: 'Full Name',
      labelStyle: _textStyle(size: 15, weight: FontWeight.w500, lineHeight: 21),
      child: _ProfileTextField(
        controller: _nameController,
        icon: Icons.person_outline_rounded,
        textStyle: _textStyle(
          size: 14,
          weight: FontWeight.w400,
          lineHeight: 20,
        ),
      ),
    );
  }

  Widget _buildBioField() {
    return SizedBox(
      width: 345,
      height: 140,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bio',
            style: _textStyle(
              size: 15,
              weight: FontWeight.w500,
              lineHeight: 21,
            ),
          ),
          const SizedBox(height: 7),
          SizedBox(
            width: 345,
            height: 112,
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
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _border, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFF087A61),
                        width: 1.5,
                      ),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                Positioned(
                  right: 12,
                  bottom: 8,
                  child: Text(
                    '${_bioController.text.length}/150',
                    style: _textStyle(
                      size: 12,
                      weight: FontWeight.w400,
                      lineHeight: 16,
                      color: _textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationField() {
    return _LabeledSection(
      height: 80,
      label: 'Location',
      labelStyle: _textStyle(size: 15, weight: FontWeight.w500, lineHeight: 21),
      child: _ProfileTextField(
        controller: _locationController,
        icon: Icons.location_on_outlined,
        textStyle: _textStyle(
          size: 14,
          weight: FontWeight.w400,
          lineHeight: 20,
        ),
      ),
    );
  }

  Widget _buildDominantHandSection() {
    return SizedBox(
      width: 345,
      height: 68,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dominant Hand',
            style: _textStyle(
              size: 15,
              weight: FontWeight.w500,
              lineHeight: 21,
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: _buildChoice(
                  label: 'Left',
                  selected: _dominantHand == 'Left',
                  onTap: () => setState(() => _dominantHand = 'Left'),
                ),
              ),
              const SizedBox(width: 8),
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
      height: 68,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Preferred Mode',
            style: _textStyle(
              size: 15,
              weight: FontWeight.w500,
              lineHeight: 21,
            ),
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: _buildChoice(
                  label: 'Singles',
                  selected: _preferredMode == 'Singles',
                  onTap: () => setState(() => _preferredMode = 'Singles'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildChoice(
                  label: 'Doubles',
                  selected: _preferredMode == 'Doubles',
                  onTap: () => setState(() => _preferredMode = 'Doubles'),
                ),
              ),
              const SizedBox(width: 8),
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
          color: selected ? _primary : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? _primary : const Color(0xFFD6DCD8),
            width: 1,
          ),
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
        onPressed: () {
          FocusScope.of(context).unfocus();

          // Sau này gọi API cập nhật profile tại đây.
          Navigator.of(context).pop();
        },
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
        child: Text(
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

class _LabeledSection extends StatelessWidget {
  const _LabeledSection({
    required this.height,
    required this.label,
    required this.labelStyle,
    required this.child,
  });

  final double height;
  final String label;
  final TextStyle labelStyle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 345,
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: labelStyle),
          const SizedBox(height: 7),
          child,
        ],
      ),
    );
  }
}

class _ProfileTextField extends StatelessWidget {
  const _ProfileTextField({
    required this.controller,
    required this.icon,
    required this.textStyle,
  });

  final TextEditingController controller;
  final IconData icon;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 345,
      height: 52,
      child: TextField(
        controller: controller,
        style: textStyle,
        textAlignVertical: TextAlignVertical.center,
        decoration: InputDecoration(
          filled: true,
          fillColor: Colors.white,
          prefixIcon: Icon(icon, size: 20, color: const Color(0xFF054D3F)),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 48,
            minHeight: 52,
          ),
          contentPadding: const EdgeInsets.only(left: 16, right: 16),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFC6D2CC), width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFF087A61), width: 1.5),
          ),
        ),
      ),
    );
  }
}

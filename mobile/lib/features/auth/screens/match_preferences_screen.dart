import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

class MatchPreferencesScreen extends StatefulWidget {
  const MatchPreferencesScreen({super.key});

  @override
  State<MatchPreferencesScreen> createState() => _MatchPreferencesScreenState();
}

class _MatchPreferencesScreenState extends State<MatchPreferencesScreen> {
  static const Color _background = Color(0xFFF7F8F5);
  static const Color _primary = Color(0xFF05644F);
  static const Color _textPrimary = Color(0xFF1C1C1C);
  static const Color _textSecondary = Color(0xFF65706B);
  static const Color _border = Color(0xFFD6DCD8);
  static const Color _mint = Color(0xFFE8F4EF);

  final Set<String> _selectedDays = {'Mon', 'Wed', 'Fri'};

  String _fromTime = '18:00';
  String _toTime = '22:00';
  String _playingMode = 'Doubles';
  String _opponentLevel = 'Intermediate';
  String _playStyle = 'Balanced';

  TextStyle _style({
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
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                      child: Column(
                        children: [
                          _buildIntroduction(),
                          const SizedBox(height: 10),
                          _buildAvailability(),
                          const SizedBox(height: 10),
                          _buildPlayingMode(),
                          const SizedBox(height: 10),
                          _buildOpponentLevel(),
                          const SizedBox(height: 10),
                          _buildPlayStyle(),
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
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 22,
                        color: _textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Match Preferences',
                      textAlign: TextAlign.center,
                      style: _style(
                        size: 22,
                        weight: FontWeight.w700,
                        lineHeight: 30,
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroduction() {
    return Container(
      width: 345,
      height: 72,
      decoration: BoxDecoration(
        color: _mint,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          _IconBadge(size: 44, asset: 'assets/icons/preferences_racket.svg'),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set your preferences',
                  style: _style(
                    size: 16,
                    weight: FontWeight.w600,
                    lineHeight: 22,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Help us find the best matches for you.',
                  style: _style(
                    size: 11,
                    weight: FontWeight.w400,
                    lineHeight: 15,
                    color: _textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvailability() {
    return SizedBox(
      width: 345,
      height: 212,
      child: Stack(
        children: [
          Positioned(
            left: 12,
            top: 8,
            child: _IconBadge(
              size: 36,
              asset: 'assets/icons/preferences_racket.svg',
            ),
          ),
          Positioned(
            left: 56,
            top: 8,
            child: Text(
              'Availability',
              style: _style(size: 18, weight: FontWeight.w600, lineHeight: 24),
            ),
          ),
          Positioned(
            left: 56,
            top: 32,
            child: Text(
              'Select the days and time you’re usually free to play.',
              style: _style(
                size: 11,
                weight: FontWeight.w400,
                lineHeight: 15,
                color: _textSecondary,
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: 56,
            child: SizedBox(
              width: 313,
              height: 68,
              child: Column(
                children: [
                  Row(
                    children: [
                      _buildDayChip('Mon'),
                      const SizedBox(width: 7),
                      _buildDayChip('Tue'),
                      const SizedBox(width: 7),
                      _buildDayChip('Wed'),
                      const SizedBox(width: 7),
                      _buildDayChip('Thu'),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildDayChip('Fri'),
                      const SizedBox(width: 7),
                      _buildDayChip('Sat'),
                      const SizedBox(width: 7),
                      _buildDayChip('Sun'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 16,
            top: 132,
            child: SizedBox(
              width: 313,
              height: 68,
              child: Row(
                children: [
                  Expanded(
                    child: _buildTimeSelector(
                      label: 'From',
                      value: _fromTime,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _fromTime = value);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildTimeSelector(
                      label: 'To',
                      value: _toTime,
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _toTime = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: Divider(height: 1, thickness: 1, color: Color(0xFFD8E2DD)),
          ),
        ],
      ),
    );
  }

  Widget _buildDayChip(String day) {
    final bool selected = _selectedDays.contains(day);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          setState(() {
            if (selected) {
              _selectedDays.remove(day);
            } else {
              _selectedDays.add(day);
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _primary : Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: selected ? _primary : _border, width: 1),
          ),
          child: Text(
            day,
            style: _style(
              size: 12,
              weight: FontWeight.w500,
              lineHeight: 18,
              color: selected ? Colors.white : _textPrimary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSelector({
    required String label,
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    const values = [
      '06:00',
      '08:00',
      '10:00',
      '14:00',
      '16:00',
      '18:00',
      '20:00',
      '22:00',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: _style(
            size: 11,
            weight: FontWeight.w500,
            lineHeight: 15,
            color: const Color(0xFF5A6661),
          ),
        ),
        const SizedBox(height: 5),
        Container(
          height: 47,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: _border, width: 1),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: _primary,
                size: 20,
              ),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              style: _style(size: 14, weight: FontWeight.w400, lineHeight: 20),
              items: values.map((time) {
                return DropdownMenuItem<String>(value: time, child: Text(time));
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayingMode() {
    return _buildPreferenceSection(
      asset: 'assets/icons/preferences_racket.svg',
      title: 'Preferred Playing Mode',
      subtitle: 'What do you usually play?',
      options: const ['Singles', 'Doubles', 'Both'],
      selected: _playingMode,
      onSelected: (value) {
        setState(() => _playingMode = value);
      },
      showDivider: true,
    );
  }

  Widget _buildOpponentLevel() {
    return _buildPreferenceSection(
      asset: 'assets/icons/preferences_shield.svg',
      title: 'Preferred Opponent Level',
      subtitle: 'What skill level do you prefer?',
      options: const ['Beginner', 'Intermediate', 'Advanced'],
      selected: _opponentLevel,
      onSelected: (value) {
        setState(() => _opponentLevel = value);
      },
      showDivider: true,
    );
  }

  Widget _buildPlayStyle() {
    return _buildPreferenceSection(
      asset: 'assets/icons/preferences_court.svg',
      title: 'Play Style',
      subtitle: 'Your playing style',
      options: const ['Offensive', 'Defensive', 'Balanced'],
      selected: _playStyle,
      onSelected: (value) {
        setState(() => _playStyle = value);
      },
      showDivider: false,
    );
  }

  Widget _buildPreferenceSection({
    required String asset,
    required String title,
    required String subtitle,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
    required bool showDivider,
  }) {
    return SizedBox(
      width: 345,
      height: 92,
      child: Stack(
        children: [
          Positioned(
            left: 12,
            top: 8,
            child: _IconBadge(size: 36, asset: asset),
          ),
          Positioned(
            left: 56,
            top: 8,
            child: Text(
              title,
              style: _style(size: 16, weight: FontWeight.w600, lineHeight: 22),
            ),
          ),
          Positioned(
            left: 56,
            top: 32,
            child: Text(
              subtitle,
              style: _style(
                size: 11,
                weight: FontWeight.w400,
                lineHeight: 15,
                color: _textSecondary,
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 18,
            top: 52,
            child: Row(
              children: [
                for (int index = 0; index < options.length; index++) ...[
                  Expanded(
                    child: _buildChoiceChip(
                      label: options[index],
                      selected: selected == options[index],
                      onTap: () => onSelected(options[index]),
                    ),
                  ),
                  if (index != options.length - 1) const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          if (showDivider)
            const Positioned(
              left: 16,
              right: 16,
              bottom: 0,
              child: Divider(height: 1, thickness: 1, color: Color(0xFFD8E2DD)),
            ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip({
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
          border: Border.all(color: selected ? _primary : _border, width: 1),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: _style(
            size: 12,
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
          final preferences = {
            'days': _selectedDays.toList(),
            'fromTime': _fromTime,
            'toTime': _toTime,
            'playingMode': _playingMode,
            'opponentLevel': _opponentLevel,
            'playStyle': _playStyle,
          };

          debugPrint('Match preferences: $preferences');

          Navigator.of(context).pop();
        },
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        child: Text(
          'Save Preferences',
          style: _style(
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

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.size, required this.asset});

  final double size;
  final String asset;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Color(0xFFDDF1E8),
        shape: BoxShape.circle,
      ),
      child: SvgPicture.asset(asset, width: size * 0.55, height: size * 0.55),
    );
  }
}

import '../../../core/theme/app_motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../widgets/sprint2_presentation.dart';
import '../services/match_preferences_service.dart';
import '../../../core/network/api_client.dart';

class MatchPreferencesScreen extends StatefulWidget {
  const MatchPreferencesScreen({super.key});

  @override
  State<MatchPreferencesScreen> createState() => _MatchPreferencesScreenState();
}

class _MatchPreferencesScreenState extends State<MatchPreferencesScreen> {
  static const Color _background = Color(0xFFF7F8F5);
  static const Color _primary = Color(0xFF05644F);
  static const Color _textPrimary = Color(0xFF142824);
  static const Color _textSecondary = Color(0xFF64716D);

  final Set<String> _selectedDays = {'Mon', 'Wed', 'Fri'};

  String _fromTime = '18:00';
  String _toTime = '22:00';
  String _playingMode = 'Doubles';
  String _opponentLevel = 'Intermediate';
  String _playStyle = 'Balanced';
  bool _loading = false, _saving = false, _loaded = false;
  String? _error;
  Map<String, dynamic>? _existingPreference;
  List<Map<String, dynamic>> _existingAvailability = [];
  bool get _preview => ApiClient.instance.token == null;
  static const _dayIds = {
    'Sun': 0,
    'Mon': 1,
    'Tue': 2,
    'Wed': 3,
    'Thu': 4,
    'Fri': 5,
    'Sat': 6,
  };

  @override
  void initState() {
    super.initState();
    if (_preview) {
      _selectedDays
        ..clear()
        ..addAll(MatchPreferencesPreview.days);
      _fromTime = MatchPreferencesPreview.from;
      _toTime = MatchPreferencesPreview.to;
      _playingMode = MatchPreferencesPreview.mode;
      _opponentLevel = MatchPreferencesPreview.level;
      _playStyle = MatchPreferencesPreview.style;
    } else {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await MatchPreferencesService.instance.load();
      if (!mounted) return;
      setState(() {
        _existingPreference = data.preference;
        _existingAvailability = data.availability;
        _selectedDays
          ..clear()
          ..addAll(
            _dayIds.keys.where(
              (d) => data.availability.any((s) => s['dayOfWeek'] == _dayIds[d]),
            ),
          );
        if (data.availability.isNotEmpty) {
          _fromTime = data.availability.first['startTime'].toString().substring(
            0,
            5,
          );
          _toTime = data.availability.first['endTime'].toString().substring(
            0,
            5,
          );
        }
        if (data.preference != null) {
          _playingMode = data.preference!['preferredMode'] == 'SINGLES'
              ? 'Singles'
              : 'Doubles';
          final min = data.preference!['minSkillLevel'] as int;
          _opponentLevel = min >= 5
              ? 'Advanced'
              : min >= 3
              ? 'Intermediate'
              : 'Beginner';
        }
        _loading = false;
        _loaded = true;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _save() async {
    if (_loading || _saving) return;
    if (_selectedDays.isEmpty || _fromTime.compareTo(_toTime) >= 0) {
      setState(
        () => _error =
            'Select at least one day and an end time after the start time.',
      );
      return;
    }
    if (!_preview && !_loaded) {
      await _load();
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (_preview) {
        MatchPreferencesPreview.days = {..._selectedDays};
        MatchPreferencesPreview.from = _fromTime;
        MatchPreferencesPreview.to = _toTime;
        MatchPreferencesPreview.mode = _playingMode;
        MatchPreferencesPreview.level = _opponentLevel;
        MatchPreferencesPreview.style = _playStyle;
      } else {
        final bounds = switch (_opponentLevel) {
          'Beginner' => (1, 2),
          'Advanced' => (5, 5),
          _ => (3, 4),
        };
        await MatchPreferencesService.instance.save(
          mode: _playingMode,
          minLevel: bounds.$1,
          maxLevel: bounds.$2,
          days: _selectedDays.map((d) => _dayIds[d]!).toSet(),
          from: _fromTime,
          to: _toTime,
          existingPreference: _existingPreference,
          existingAvailability: _existingAvailability,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _preview ? 'UI preview: preferences saved for this session only.' : 'Availability and preferences saved. Play Style is not supported by the current API.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _loaded = false;
          _error = error.toString();
        });
      }
    }
  }

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
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.dark,
    child: Scaffold(
      backgroundColor: _background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 393),
          child: Column(
            children: [
              const Sprint2BackHeader(title: 'Match Preferences'),
              Expanded(
                child: Sprint2FormBody(
                  button: _buildSaveButton(),
                  children: [
                    if (_loading) const LinearProgressIndicator(),
                    if (_error != null)
                      MaterialBanner(
                        content: Text(_error!),
                        actions: [
                          TextButton(
                            onPressed: _load,
                            child: const Text('Reload'),
                          ),
                        ],
                      ),
                    _buildAvailability(),
                    _buildPlayingMode(),
                    _buildOpponentLevel(),
                    _buildPlayStyle(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _buildAvailability() => Container(
    constraints: const BoxConstraints(minHeight: 254),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeader(
          'assets/icons/sprint2_preferences_Sprint3IconCalendar.svg',
          'Availability',
          'Choose your usual days and time.',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildDayChip('Mon'),
            const SizedBox(width: 8),
            _buildDayChip('Tue'),
            const SizedBox(width: 8),
            _buildDayChip('Wed'),
            const SizedBox(width: 8),
            _buildDayChip('Thu'),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildDayChip('Fri'),
            const SizedBox(width: 8),
            _buildDayChip('Sat'),
            const SizedBox(width: 8),
            _buildDayChip('Sun'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
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
            const SizedBox(width: 16),
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
      ],
    ),
  );

  Widget _sectionHeader(String asset, String title, String subtitle) => Row(
    children: [
      _IconBadge(size: 36, asset: asset),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: _style(size: 16, weight: FontWeight.w600, lineHeight: 22),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: _style(
                size: 12,
                weight: FontWeight.w400,
                lineHeight: 16,
                color: _textSecondary,
              ),
            ),
          ],
        ),
      ),
    ],
  );

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
          duration: AppMotion.duration(context, 160),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? _primary : const Color(0xFFF3F6F3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            day,
            style: _style(
              size: 13,
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
            size: 12,
            weight: FontWeight.w500,
            lineHeight: 16,
            color: const Color(0xFF5A6661),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F6F3),
            borderRadius: BorderRadius.circular(12),
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
              items: {...values, value}.toList().map((time) {
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
      asset: 'assets/icons/sprint2_preferences_Vector.svg',
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
      asset: 'assets/icons/sprint2_preferences_Frame1.svg',
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
      asset: 'assets/icons/sprint2_preferences_Frame.svg',
      title: 'Play Style',
      subtitle: 'Choose the style that fits you.',
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
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionHeader(asset, title, subtitle),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: Row(
              children: [
                for (var index = 0; index < options.length; index++) ...[
                  if (index > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _buildChoiceChip(
                      label: options[index],
                      selected: selected == options[index],
                      onTap: () => onSelected(options[index]),
                      compact: title == 'Preferred Playing Mode',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.duration(context, 160),
        height: compact ? 32.661 : 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _primary : const Color(0xFFF3F6F3),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          maxLines: 1,
          style: _style(
            size: compact ? 10.89 : 12,
            weight: FontWeight.w500,
            lineHeight: compact ? 15.423 : 17,
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
        onPressed: _loading || _saving ? null : _save,
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
        child: _saving
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
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
        color: Color(0xFFEAF3EF),
        shape: BoxShape.circle,
      ),
      child: SvgPicture.asset(
        asset,
        width: asset.endsWith('_Vector.svg') ? 16 : 20,
        height: asset.endsWith('_Vector.svg') ? 16 : 20,
      ),
    );
  }
}

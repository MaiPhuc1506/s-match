import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../booking_theme.dart';

/// Centered dialog over the full-screen schedule; only Confirm commits the date.
String bookingMonthLabel(DateTime date) {
  const months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return '${months[date.month - 1]} ${date.year}';
}

Future<DateTime?> showBookingMonthPicker({
  required BuildContext context,
  required DateTime selectedDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) => showDialog<DateTime>(
  context: context,
  barrierColor: const Color(0x66000F0A),
  builder: (_) => BookingMonthPicker(
    selectedDate: selectedDate,
    firstDate: firstDate,
    lastDate: lastDate,
  ),
);

class BookingMonthPicker extends StatefulWidget {
  const BookingMonthPicker({
    super.key,
    required this.selectedDate,
    required this.firstDate,
    required this.lastDate,
  });
  final DateTime selectedDate, firstDate, lastDate;
  @override
  State<BookingMonthPicker> createState() => _BookingMonthPickerState();
}

class _BookingMonthPickerState extends State<BookingMonthPicker> {
  late DateTime selected = DateUtils.dateOnly(widget.selectedDate);
  late DateTime month = DateTime(selected.year, selected.month);
  bool valid(DateTime day) =>
      !day.isBefore(DateUtils.dateOnly(widget.firstDate)) &&
      !day.isAfter(DateUtils.dateOnly(widget.lastDate));
  bool canMove(int offset) {
    final target = DateTime(month.year, month.month + offset);
    final end = DateTime(target.year, target.month + 1, 0);
    return !end.isBefore(DateUtils.dateOnly(widget.firstDate)) &&
        !target.isAfter(DateUtils.dateOnly(widget.lastDate));
  }

  @override
  Widget build(BuildContext context) {
    final offset = (month.weekday + 6) % 7;
    final days = DateUtils.getDaysInMonth(month.year, month.month);
    final rows = ((offset + days) / 7).ceil();
    return Dialog(
      key: const Key('booking-month-dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: BookingColors.cardBg,
      elevation: 8,
      shadowColor: const Color(0x3300170F),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 356),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  _arrow(-1, CupertinoIcons.chevron_left, 'Previous month'),
                  Expanded(
                    child: Text(
                      bookingMonthLabel(month),
                      textAlign: TextAlign.center,
                      style: BookingTypography.jakarta(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _arrow(1, CupertinoIcons.chevron_right, 'Next month'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final label in [
                    'Mon',
                    'Tue',
                    'Wed',
                    'Thu',
                    'Fri',
                    'Sat',
                    'Sun',
                  ])
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: BookingTypography.jakarta(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: BookingColors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              for (var row = 0; row < rows; row++)
                Row(
                  children: [
                    for (var col = 0; col < 7; col++)
                      Expanded(child: _day(row * 7 + col - offset + 1, days)),
                  ],
                ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  CupertinoButton(
                    key: const Key('booking-month-cancel'),
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: BookingTypography.jakarta(
                        fontSize: 14,
                        color: BookingColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    key: const Key('booking-month-confirm'),
                    color: BookingColors.primary,
                    borderRadius: BorderRadius.circular(12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    onPressed: valid(selected)
                        ? () => Navigator.pop(context, selected)
                        : null,
                    child: Text(
                      'Confirm',
                      style: BookingTypography.jakarta(
                        fontSize: 14,
                        color: BookingColors.cardBg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _arrow(int direction, IconData icon, String label) => Semantics(
    label: label,
    button: true,
    enabled: canMove(direction),
    child: CupertinoButton(
      key: ValueKey('booking-month-arrow-$direction'),
      padding: EdgeInsets.zero,
      onPressed: canMove(direction)
          ? () => setState(
              () => month = DateTime(month.year, month.month + direction),
            )
          : null,
      child: Icon(
        icon,
        size: 18,
        color: canMove(direction)
            ? BookingColors.primary
            : BookingColors.border,
      ),
    ),
  );

  Widget _day(int number, int days) {
    if (number < 1 || number > days) return const SizedBox(height: 44);
    final day = DateTime(month.year, month.month, number);
    final chosen = DateUtils.isSameDay(day, selected);
    return Padding(
      padding: const EdgeInsets.all(1),
      child: Semantics(
        selected: chosen,
        enabled: valid(day),
        label: '$number/${month.month}/${month.year}',
        child: CupertinoButton(
          key: ValueKey('booking-day-${day.year}-${day.month}-${day.day}'),
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 44),
          color: chosen ? BookingColors.primary : null,
          borderRadius: BorderRadius.circular(11),
          onPressed: valid(day) ? () => setState(() => selected = day) : null,
          child: Text(
            '$number',
            style: BookingTypography.jakarta(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: chosen
                  ? BookingColors.cardBg
                  : valid(day)
                  ? BookingColors.textDark
                  : BookingColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'booking_detail_screen.dart';
import 'booking_facility_schedule_screen.dart';
import 'booking_history_screen.dart';
import 'booking_success_screen.dart';
import 'booking_summary_screen.dart';

/// Điều phối chuyển màn hình theo đúng Prototype Reactions trong Figma
class BookingFlowScreen extends StatelessWidget {
  const BookingFlowScreen({super.key});

  void _returnToPlayerProfile(BuildContext context) {
    Navigator.of(context).popUntil(
      (route) => route.isFirst || route.settings.name == '/player-profile',
    );
  }

  @override
  Widget build(BuildContext context) {
    return BookingFacilityScheduleScreen(
      // Màn 01 -> Màn 02 (Booking Summary)
      onContinue: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookingSummaryScreen(
              // Màn 02 -> Màn 03 (Booking Success)
              onConfirm: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookingSuccessScreen(
                      // Màn 03 -> Màn 04 (Booking History)
                      onViewBookings: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BookingHistoryScreen(
                              // Màn 04 -> Màn 05 (Booking Detail khi bấm vào card Sân 3)
                              onSelectBooking: (item) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => BookingDetailScreen(
                                      bookingId: item.id,
                                      facilityName: item.facilityName,
                                      courtName: item.courtName,
                                      priceText: item.priceText,
                                    ),
                                  ),
                                );
                              },
                              onNavigateHome: () {
                                _returnToPlayerProfile(context);
                              },
                              onNavigateProfile: () {
                                _returnToPlayerProfile(context);
                              },
                            ),
                          ),
                        );
                      },
                      onBackHome: () {
                        _returnToPlayerProfile(context);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

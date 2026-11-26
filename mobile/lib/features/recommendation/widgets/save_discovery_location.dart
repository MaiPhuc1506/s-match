import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/network/api_client.dart';

/// Saves only an explicitly requested device position for the current session.
class SaveDiscoveryLocation extends StatefulWidget {
  const SaveDiscoveryLocation({
    super.key,
    required this.onSaved,
    this.label = 'Use current location',
  });
  final VoidCallback onSaved;
  final String label;

  @override
  State<SaveDiscoveryLocation> createState() => _SaveDiscoveryLocationState();
}

class _SaveDiscoveryLocationState extends State<SaveDiscoveryLocation> {
  bool busy = false;
  late final String? sessionToken = ApiClient.instance.token;

  Future<void> save() async {
    if (busy) return;
    final client = ApiClient.instance;
    final token = sessionToken;
    if (token == null || client.token != token) return;
    setState(() => busy = true);
    String? message;
    bool settings = false;
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        message = 'Turn on Location Services and try again.';
      } else {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.deniedForever) {
          message = 'Location access is blocked. Enable it in Settings.';
          settings = true;
        } else if (permission == LocationPermission.denied ||
            permission == LocationPermission.unableToDetermine) {
          message = 'Location permission is needed to save your location.';
        } else {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 15),
            ),
          );
          if (!position.latitude.isFinite ||
              !position.longitude.isFinite ||
              position.latitude.abs() > 90 ||
              position.longitude.abs() > 180 ||
              !position.accuracy.isFinite ||
              position.accuracy < 0 ||
              position.accuracy > 1000) {
            message = 'Your location is unavailable or not accurate enough. Please try again.';
          } else if (mounted && client.token == token) {
            await client.dio.put(
              '/candidates/me/location',
              data: {
                'latitude': position.latitude,
                'longitude': position.longitude,
              },
              options: Options(extra: {'expectedAuthToken': token}),
            );
            if (mounted && client.token == token) widget.onSaved();
          }
        }
      }
    } catch (_) {
      message = 'Could not save your location. Please try again.';
    } finally {
      if (mounted) {
        setState(() => busy = false);
        if (message != null && client.token == token) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              action: settings
                  ? SnackBarAction(
                      label: 'Settings',
                      onPressed: Geolocator.openAppSettings,
                    )
                  : null,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: busy ? null : save,
    child: Text(busy ? 'Saving location…' : widget.label),
  );
}

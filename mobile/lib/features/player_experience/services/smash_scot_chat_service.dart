import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../models/chat_message.dart';

class SmashScotChatService {
  SmashScotChatService({Dio? dio, String? Function()? tokenProvider})
    : _dio = dio ?? ApiClient.instance.dio,
      _tokenProvider = tokenProvider ?? (() => ApiClient.instance.token);

  final Dio _dio;
  final String? Function() _tokenProvider;

  bool get hasActiveSession {
    final token = _tokenProvider();
    return token != null && token.trim().isNotEmpty;
  }

  Future<String> sendMessage(
    String message, {
    List<ChatMessage> history = const [],
  }) async => (await sendRichMessage(message, history: history)).text;

  Future<ChatMessage> sendRichMessage(
    String message, {
    List<ChatMessage> history = const [],
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return ChatMessage(
        id: '',
        text: 'Please enter a message for Smash Scot.',
        isUser: false,
      );
    }

    // Build compact multi-turn history (last 8 messages, excluding initial greeting bubble id='1')
    final recentHistory = history
        .where((m) => m.id != '1' && m.text.trim().isNotEmpty)
        .toList();
    final startIdx = recentHistory.length > 8 ? recentHistory.length - 8 : 0;
    final historyPayload = recentHistory
        .sublist(startIdx)
        .map(
          (m) => {
            'role': m.isUser ? 'user' : 'assistant',
            'content': m.text.length > 1000
                ? m.text.substring(0, 1000)
                : m.text,
          },
        )
        .toList();

    Map<String, double>? nearby;
    final radiusMatch = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(km|kilometers?|kilometres?)\b',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (radiusMatch != null) {
      final radius = double.tryParse(
        radiusMatch.group(1)!.replaceAll(',', '.'),
      );
      if (radius == null || radius < 0.05 || radius > 100) {
        return ChatMessage(
          id: 'radius',
          text: 'Please choose a radius between 0.05 and 100 km.',
          isUser: false,
        );
      }
      try {
        if (!await Geolocator.isLocationServiceEnabled()) {
          throw StateError('disabled');
        }
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          throw StateError('denied');
        }
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 12),
          ),
        );
        if (!position.accuracy.isFinite || position.accuracy > 200) {
          throw StateError('inaccurate');
        }
        nearby = {
          'latitude': position.latitude,
          'longitude': position.longitude,
          'radiusKm': radius,
        };
      } catch (_) {
        return ChatMessage(
          id: 'location',
          text: 'Unable to use your current location. Enable location permission and try again to search by distance.',
          isUser: false,
        );
      }
    }
    final response = await _dio.post<Map<String, dynamic>>(
      '/ai/chat',
      options: Options(receiveTimeout: const Duration(seconds: 100)),
      data: {
        'nearby': ?nearby,
        'message': trimmed.length > 1000 ? trimmed.substring(0, 1000) : trimmed,
        if (historyPayload.isNotEmpty) 'history': historyPayload,
      },
    );

    final reply = response.data?['reply'];
    if (reply is String && reply.trim().isNotEmpty) {
      final results =
          (response.data?['courtResults'] as List?)
              ?.whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          const <Map<String, dynamic>>[];
      return ChatMessage(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: reply.trim(),
        isUser: false,
        courtResults: results,
      );
    }
    throw const FormatException('Empty reply from /ai/chat');
  }
}

final smashScotChatServiceProvider = Provider<SmashScotChatService>(
  (ref) => SmashScotChatService(),
);

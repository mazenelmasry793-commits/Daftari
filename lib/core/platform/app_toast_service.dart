import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum AppToastType { success, error, warning, info }

extension AppToastTypeValues on AppToastType {
  String get wireValue => name;

  IconData get fallbackIcon {
    switch (this) {
      case AppToastType.success:
        return Icons.check_circle_rounded;
      case AppToastType.error:
        return Icons.cancel_rounded;
      case AppToastType.warning:
        return Icons.warning_rounded;
      case AppToastType.info:
        return Icons.info_rounded;
    }
  }
}

const appToastChannelName = 'com.daftari/native_toast';
final appScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class AppToastService {
  AppToastService({
    MethodChannel? channel,
    bool Function()? isIos,
    GlobalKey<ScaffoldMessengerState>? messengerKey,
    DateTime Function()? now,
  }) : _channel = channel ?? const MethodChannel(appToastChannelName),
       _isIos = isIos ?? (() => !kIsWeb && Platform.isIOS),
       _messengerKey = messengerKey ?? appScaffoldMessengerKey,
       _now = now ?? DateTime.now;

  final MethodChannel _channel;
  final bool Function() _isIos;
  final GlobalKey<ScaffoldMessengerState> _messengerKey;
  final DateTime Function() _now;
  String? _lastMessage;
  DateTime? _lastShownAt;

  Future<void> show(
    String message, {
    AppToastType type = AppToastType.info,
    Duration duration = const Duration(milliseconds: 2200),
  }) async {
    final text = message.trim();
    if (text.isEmpty || _isDuplicate(text)) return;

    _lastMessage = text;
    _lastShownAt = _now();
    final durationMs = duration.inMilliseconds.clamp(1400, 6000).toInt();

    if (_isIos()) {
      try {
        await _channel.invokeMethod<void>('showToast', {
          'message': text,
          'type': type.wireValue,
          'durationMs': durationMs,
        });
        return;
      } on PlatformException catch (error) {
        debugPrint('Native toast unavailable: $error');
      } on MissingPluginException catch (error) {
        debugPrint('Native toast plugin unavailable: $error');
      }
    }

    _showFlutterFallback(text, type, Duration(milliseconds: durationMs));
  }

  bool _isDuplicate(String message) {
    final lastShownAt = _lastShownAt;
    return lastShownAt != null &&
        _lastMessage == message &&
        _now().difference(lastShownAt) < const Duration(milliseconds: 600);
  }

  void _showFlutterFallback(
    String message,
    AppToastType type,
    Duration duration,
  ) {
    final messenger = _messengerKey.currentState;
    if (messenger == null) return;

    final colorScheme = Theme.of(messenger.context).colorScheme;
    final accent = switch (type) {
      AppToastType.success => colorScheme.primary,
      AppToastType.error => colorScheme.error,
      AppToastType.warning => colorScheme.tertiary,
      AppToastType.info => colorScheme.secondary,
    };

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: duration,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          backgroundColor: colorScheme.surfaceContainerHighest,
          content: Row(
            children: [
              Icon(type.fallbackIcon, color: accent),
              const SizedBox(width: 10),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      );
  }
}

final appToastService = AppToastService();

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

typedef OnAddEntryTypeSelected = void Function(String type);
typedef OnNativeEntryFormSubmitted = Future<bool> Function(
  Map<String, dynamic> payload,
);

class NativeSheetsChannel {
  NativeSheetsChannel({
    MethodChannel? channel,
    bool Function()? isIos,
  })  : _channel = channel ?? const MethodChannel('com.daftari/native_sheets'),
        _isIos = isIos ?? (() => !kIsWeb && Platform.isIOS) {
    _channel.setMethodCallHandler(handleNativeCall);
  }

  final MethodChannel _channel;
  final bool Function() _isIos;

  OnAddEntryTypeSelected? onAddEntryTypeSelected;
  OnNativeEntryFormSubmitted? onNativeEntryFormSubmitted;

  Future<void> showAddEntryChooser() async {
    if (!_isIos()) return;
    try {
      await _channel.invokeMethod('showAddEntryChooser');
    } on PlatformException catch (e) {
      debugPrint('Error invoking showAddEntryChooser: $e');
    }
  }

  Future<void> showNativeEntryForm({required String type}) async {
    if (!_isIos()) return;
    try {
      await _channel.invokeMethod('showNativeEntryForm', {'type': type});
    } on PlatformException catch (e) {
      debugPrint('Error invoking showNativeEntryForm: $e');
    }
  }

  Future<DateTime?> showNativeDatePicker({
    required DateTime initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    if (!_isIos()) return null;
    try {
      final isoResult = await _channel.invokeMethod<String>(
        'showNativeDatePicker',
        {
          'initialDate': initialDate.toIso8601String(),
          if (firstDate != null) 'minimumDate': firstDate.toIso8601String(),
          if (lastDate != null) 'maximumDate': lastDate.toIso8601String(),
        },
      );
      if (isoResult != null) {
        return DateTime.tryParse(isoResult);
      }
    } on PlatformException catch (e) {
      debugPrint('Error invoking showNativeDatePicker: $e');
    }
    return null;
  }

  @visibleForTesting
  Future<dynamic> handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'addEntryTypeSelected':
        final args = call.arguments as Map<dynamic, dynamic>?;
        final type = args?['type'] as String?;
        if (type != null && onAddEntryTypeSelected != null) {
          onAddEntryTypeSelected!(type);
        }
        break;
      case 'addEntryChooserDismissed':
        break;
      case 'nativeEntryFormSubmitted':
        final rawArgs = call.arguments as Map<dynamic, dynamic>?;
        final args = rawArgs == null
            ? <String, dynamic>{}
            : Map<String, dynamic>.from(rawArgs);
        final callback = onNativeEntryFormSubmitted;
        if (callback == null) return false;
        return callback(args);
    }
  }
}

final nativeSheetsChannel = NativeSheetsChannel();

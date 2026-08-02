import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

const _channelName = 'com.daftari/native_entry_details';

class NativeEntryDetailsChannel {
  NativeEntryDetailsChannel({MethodChannel? channel, bool Function()? isIos})
    : _channel = channel ?? const MethodChannel(_channelName),
      _isIos = isIos ?? (() => Platform.isIOS) {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  final MethodChannel _channel;
  final bool Function() _isIos;
  Future<Map<String, dynamic>> Function(String id)? onLoadEntry;
  Future<Map<String, dynamic>> Function(
    String id,
    String action,
    int? paymentId,
  )?
  onPerformAction;

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'loadEntry':
        final id = _id(call.arguments);
        return id == null ? null : onLoadEntry?.call(id);
      case 'performAction':
        final args = call.arguments;
        if (args is! Map ||
            args['id'] is! String ||
            args['action'] is! String) {
          return null;
        }
        return onPerformAction?.call(
          args['id'] as String,
          args['action'] as String,
          args['paymentID'] is int ? args['paymentID'] as int : null,
        );
      default:
        throw MissingPluginException(
          'Unknown native entry details method: ${call.method}',
        );
    }
  }

  @visibleForTesting
  Future<dynamic> handleNativeCall(MethodCall call) => _handleNativeCall(call);

  String? _id(dynamic arguments) =>
      arguments is Map && arguments['id'] is String
      ? arguments['id'] as String
      : null;

  Future<void> updateSnapshot(Map<String, dynamic> payload) async {
    if (!_isIos()) return;
    await _channel.invokeMethod<void>('entryDetailsSnapshotUpdated', payload);
  }

  Future<void> close() async {
    if (!_isIos()) return;
    await _channel.invokeMethod<void>('closeEntryDetails');
  }
}

final nativeEntryDetailsChannel = NativeEntryDetailsChannel();

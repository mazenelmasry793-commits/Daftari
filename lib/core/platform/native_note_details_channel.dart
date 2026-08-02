import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:debt_tracker/core/utils/formatters.dart';
import 'package:debt_tracker/data/models/entry.dart';

const _channelName = 'com.daftari/native_note_details';

Map<String, dynamic> nativeNoteDetailsEntryPayload(Entry entry) {
  final date = entry.debtDate ?? entry.createdAt;
  return {
    'id': entry.id.toString(),
    'title': entry.title,
    'note': entry.note ?? '',
    'dateEpochMs': date.millisecondsSinceEpoch,
    'dateIso8601': date.toUtc().toIso8601String(),
    'dateText': AppFormatters.date.format(date),
  };
}

class NativeNoteDetailsChannel {
  NativeNoteDetailsChannel({MethodChannel? channel, bool Function()? isIos})
    : _channel = channel ?? const MethodChannel(_channelName),
      _isIos = isIos ?? (() => Platform.isIOS) {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  final MethodChannel _channel;
  final bool Function() _isIos;
  Future<Map<String, dynamic>> Function(String id)? onLoadNote;
  Future<Map<String, dynamic>> Function(
    String id,
    String action,
    Map<String, dynamic>? payload,
  )?
  onPerformAction;

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'loadNote':
        final id = _id(call.arguments);
        return id == null ? null : onLoadNote?.call(id);
      case 'performAction':
        final args = call.arguments;
        if (args is! Map ||
            args['id'] is! String ||
            args['action'] is! String) {
          return null;
        }
        final payload = <String, dynamic>{
          if (args['title'] is String) 'title': args['title'],
          if (args['note'] is String) 'note': args['note'],
          if (args['dateIso8601'] is String) 'dateIso8601': args['dateIso8601'],
        };
        return onPerformAction?.call(
          args['id'] as String,
          args['action'] as String,
          payload.isEmpty ? null : payload,
        );
      default:
        throw MissingPluginException(
          'Unknown native note details method: ${call.method}',
        );
    }
  }

  @visibleForTesting
  Future<dynamic> handleNativeCall(MethodCall call) => _handleNativeCall(call);

  Future<void> updateSnapshot(Map<String, dynamic> payload) async {
    if (!_isIos()) return;
    await _channel.invokeMethod<void>('noteDetailsSnapshotUpdated', payload);
  }

  String? _id(dynamic arguments) =>
      arguments is Map && arguments['id'] is String
      ? arguments['id'] as String
      : null;
}

final nativeNoteDetailsChannel = NativeNoteDetailsChannel();

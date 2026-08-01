import 'dart:io';

import 'package:debt_tracker/core/utils/formatters.dart';
import 'package:debt_tracker/data/models/entry.dart';
import 'package:debt_tracker/presentation/providers/app_providers.dart';
import 'package:flutter/services.dart';

const _nativeDashboardChannel = 'com.daftari/native_dashboard';
const _nativeEntriesChannel = 'com.daftari/native_entries';

class NativeDashboardChannel {
  NativeDashboardChannel({
    MethodChannel? channel,
    MethodChannel? entriesChannel,
    bool Function()? isIos,
  })
    : _channel = channel ?? const MethodChannel(_nativeDashboardChannel),
      _entriesChannel = entriesChannel ?? const MethodChannel(_nativeEntriesChannel),
      _isIos = isIos ?? (() => Platform.isIOS) {
    _channel.setMethodCallHandler(_handleNativeCall);
    _entriesChannel.setMethodCallHandler(_handleNativeCall);
  }

  final MethodChannel _channel;
  final MethodChannel _entriesChannel;
  final bool Function() _isIos;
  Map<String, dynamic>? _lastSnapshot;
  Future<void> Function(String id)? onOpenEntryDetails;

  Future<dynamic> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'dashboardReady':
        final snapshot = _lastSnapshot;
        if (snapshot != null) {
          await _channel.invokeMethod<void>(
            'dashboardSnapshotUpdated',
            snapshot,
          );
        }
        return null;
      case 'openEntryDetails':
        final arguments = call.arguments;
        final id = arguments is Map ? arguments['id'] : null;
        if (id is String) await onOpenEntryDetails?.call(id);
        return null;
      default:
        throw MissingPluginException(
          'Unknown native dashboard method: ${call.method}',
        );
    }
  }

  Future<void> updateSnapshot(Iterable<Entry> entries) async {
    if (!_isIos()) return;
    final list = entries.toList(growable: false);
    final totals = calculateDashboardTotals(list);
    final recent = list.take(6).toList(growable: false);
    final payload = <String, dynamic>{
      'schemaVersion': 1,
      'currencyCode': 'EUR',
      'currencySymbol': '€',
      'owedToMeMinor': (totals.owedToMe * 100).round(),
      'iOweMinor': (totals.iOwe * 100).round(),
      'owedToMeText': AppFormatters.money.format(totals.owedToMe),
      'iOweText': AppFormatters.money.format(totals.iOwe),
      'totalRecentCount': recent.length,
      'recentEntries': [
        for (final entry in recent)
          {
            'id': entry.id.toString(),
            'title': entry.title,
            'type': switch (entry.type) {
              EntryType.owedToMe => 'owedToMe',
              EntryType.owedByMe => 'owedByMe',
              EntryType.scratchpad => 'scratchpad',
            },
            'amountMinor':
                ((entry.type == EntryType.scratchpad
                            ? entry.amount ?? 0
                            : entry.remainingAmount) *
                        100)
                    .round(),
            'amountText': AppFormatters.money.format(
              entry.type == EntryType.scratchpad
                  ? entry.amount ?? 0
                  : entry.remainingAmount,
            ),
            'dateIso8601': (entry.debtDate ?? entry.createdAt)
                .toIso8601String(),
            'dateText': AppFormatters.date.format(
              entry.debtDate ?? entry.createdAt,
            ),
          },
      ],
      'entries': [
        for (final entry in list)
          {
            'id': entry.id.toString(),
            'title': entry.title,
            'type': switch (entry.type) {
              EntryType.owedToMe => 'owedToMe',
              EntryType.owedByMe => 'owedByMe',
              EntryType.scratchpad => 'scratchpad',
            },
            'amountText': AppFormatters.money.format(
              entry.type == EntryType.scratchpad
                  ? entry.amount ?? 0
                  : entry.remainingAmount,
            ),
            'dateText': AppFormatters.date.format(
              entry.debtDate ?? entry.createdAt,
            ),
          },
      ],
    };
    _lastSnapshot = payload;
    try {
      await _channel.invokeMethod<void>('dashboardSnapshotUpdated', payload);
      await _entriesChannel.invokeMethod<void>('entriesSnapshotUpdated', payload);
    } on PlatformException {
      // Native Dashboard is optional; Flutter remains the fallback.
    } on MissingPluginException {
      // Native Dashboard is unavailable on older iOS and Android.
    }
  }
}

final nativeDashboardChannel = NativeDashboardChannel();

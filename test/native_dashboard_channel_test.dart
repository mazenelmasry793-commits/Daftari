import 'package:debt_tracker/core/platform/native_dashboard_channel.dart';
import 'package:debt_tracker/data/models/entry.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('serializes the dashboard snapshot without changing entry order', () async {
    final channel = MethodChannel('test.native_dashboard');
    Map<Object?, Object?>? received;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'dashboardSnapshotUpdated') {
        received = call.arguments as Map<Object?, Object?>;
      }
      return null;
        });

    final nativeDashboard = NativeDashboardChannel(
      channel: channel,
      isIos: () => true,
    );
    final date = DateTime(2026, 8, 1);
    final first = _entry(1, 'Bello', EntryType.owedToMe, 2334, date);
    final second = _entry(2, 'Hey', EntryType.owedByMe, 222, date);

    await nativeDashboard.updateSnapshot([first, second]);

    expect(received?['schemaVersion'], 1);
    expect(received?['owedToMeMinor'], 233400);
    expect(received?['iOweMinor'], 22200);
    expect(received?['totalRecentCount'], 2);
    final entries = received?['recentEntries'] as List<Object?>;
    expect((entries[0] as Map<Object?, Object?>)['id'], '1');
    expect((entries[0] as Map<Object?, Object?>)['type'], 'owed_to_me');
    expect((entries[0] as Map<Object?, Object?>)['dateIso8601'],
        date.toIso8601String());
    expect((entries[1] as Map<Object?, Object?>)['id'], '2');
    expect((entries[1] as Map<Object?, Object?>)['type'], 'owed_by_me');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('does not invoke the native channel off iOS', () async {
    final channel = MethodChannel('test.native_dashboard_android');
    var invocationCount = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async {
      invocationCount++;
      return null;
        });

    final nativeDashboard = NativeDashboardChannel(
      channel: channel,
      isIos: () => false,
    );
    await nativeDashboard.updateSnapshot([_entry(
      1,
      'Bello',
      EntryType.owedToMe,
      10,
      DateTime(2026, 8, 1),
    )]);

    expect(invocationCount, 0);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}

Entry _entry(int id, String title, EntryType type, double amount, DateTime date) {
  return Entry()
    ..id = id
    ..title = title
    ..amount = amount
    ..type = type
    ..status = EntryStatus.active
    ..createdAt = date
    ..updatedAt = date
    ..debtDate = date;
}

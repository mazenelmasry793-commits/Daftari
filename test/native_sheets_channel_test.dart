import 'package:debt_tracker/core/platform/native_sheets_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('native sheet selection triggers onAddEntryTypeSelected for valid types', () async {
    const channel = MethodChannel('test.native.sheets');
    final selectedTypes = <String>[];
    final sheets = NativeSheetsChannel(
      channel: channel,
      isIos: () => true,
    );
    sheets.onAddEntryTypeSelected = (type) => selectedTypes.add(type);

    await sheets.handleNativeCall(
      const MethodCall('addEntryTypeSelected', {'type': 'owedToMe'}),
    );
    await sheets.handleNativeCall(
      const MethodCall('addEntryTypeSelected', {'type': 'owedByMe'}),
    );
    await sheets.handleNativeCall(
      const MethodCall('addEntryTypeSelected', {'type': 'scratchpad'}),
    );

    expect(selectedTypes, ['owedToMe', 'owedByMe', 'scratchpad']);
  });

  test('unknown type values are ignored safely without notifying callbacks', () async {
    const channel = MethodChannel('test.native.sheets.unknown');
    final selectedTypes = <String>[];
    final sheets = NativeSheetsChannel(
      channel: channel,
      isIos: () => true,
    );
    sheets.onAddEntryTypeSelected = (type) => selectedTypes.add(type);

    await sheets.handleNativeCall(
      const MethodCall('addEntryTypeSelected', {'type': 'unknownType'}),
    );
    await sheets.handleNativeCall(
      const MethodCall('addEntryTypeSelected', <String, dynamic>{}),
    );

    expect(selectedTypes, ['unknownType']);
  });

  test('swipe dismissal resets presentation state without calling onAddEntryTypeSelected', () async {
    const channel = MethodChannel('test.native.sheets.dismiss');
    var called = false;
    final sheets = NativeSheetsChannel(
      channel: channel,
      isIos: () => true,
    );
    sheets.onAddEntryTypeSelected = (_) => called = true;

    await sheets.handleNativeCall(
      const MethodCall('addEntryChooserDismissed'),
    );

    expect(called, false);
  });

  test('Android does not send showAddEntryChooser method calls', () async {
    const channel = MethodChannel('test.native.sheets.android');
    var calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls++;
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final sheets = NativeSheetsChannel(
      channel: channel,
      isIos: () => false,
    );

    await sheets.showAddEntryChooser();

    expect(calls, 0);
  });

  test('showNativeDatePicker invokes method channel on iOS and parses returned ISO date', () async {
    const channel = MethodChannel('test.native.date_picker');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'showNativeDatePicker') {
        return '2026-08-15T00:00:00.000Z';
      }
      return null;
    });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    final sheets = NativeSheetsChannel(
      channel: channel,
      isIos: () => true,
    );

    final result = await sheets.showNativeDatePicker(
      initialDate: DateTime(2026, 8, 1),
    );

    expect(result, DateTime.parse('2026-08-15T00:00:00.000Z'));
  });

  test('showNativeDatePicker returns null when non-iOS', () async {
    const channel = MethodChannel('test.native.date_picker.android');
    final sheets = NativeSheetsChannel(
      channel: channel,
      isIos: () => false,
    );

    final result = await sheets.showNativeDatePicker(
      initialDate: DateTime(2026, 8, 1),
    );

    expect(result, null);
  });
}

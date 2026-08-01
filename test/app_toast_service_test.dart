import 'package:debt_tracker/core/platform/app_toast_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('routes native toast requests with the expected payload', () async {
    final channel = MethodChannel(appToastChannelName);
    MethodCall? receivedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          receivedCall = call;
          return null;
        });

    final service = AppToastService(channel: channel, isIos: () => true);
    await service.show(
      'Entry saved',
      type: AppToastType.success,
      duration: const Duration(seconds: 2),
    );

    expect(receivedCall?.method, 'showToast');
    expect(receivedCall?.arguments, {
      'message': 'Entry saved',
      'type': 'success',
      'durationMs': 2000,
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets(
    'falls back to a floating snackbar when native toast is unavailable',
    (tester) async {
      final messengerKey = GlobalKey<ScaffoldMessengerState>();
      await tester.pumpWidget(
        MaterialApp(
          scaffoldMessengerKey: messengerKey,
          home: const Scaffold(body: SizedBox()),
        ),
      );
      final channel = MethodChannel('$appToastChannelName/fallback');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            throw MissingPluginException();
          });

      final service = AppToastService(
        channel: channel,
        isIos: () => true,
        messengerKey: messengerKey,
      );
      await service.show('Something went wrong', type: AppToastType.error);
      await tester.pump();

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_rounded), findsOneWidget);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    },
  );

  testWidgets('uses the Flutter fallback on non-iOS platforms', (tester) async {
    final messengerKey = GlobalKey<ScaffoldMessengerState>();
    await tester.pumpWidget(
      MaterialApp(
        scaffoldMessengerKey: messengerKey,
        home: const Scaffold(body: SizedBox()),
      ),
    );
    final service = AppToastService(
      isIos: () => false,
      messengerKey: messengerKey,
    );

    await service.show('Import completed', type: AppToastType.success);
    await tester.pump();

    expect(find.text('Import completed'), findsOneWidget);
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  test(
    'suppresses identical messages fired within the duplicate window',
    () async {
      var now = DateTime(2026, 1, 1);
      var callCount = 0;
      final channel = MethodChannel('$appToastChannelName/duplicates');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            callCount++;
            return null;
          });
      final service = AppToastService(
        channel: channel,
        isIos: () => true,
        now: () => now,
      );

      await service.show('Payment added');
      now = now.add(const Duration(milliseconds: 300));
      await service.show('Payment added');
      expect(callCount, 1);

      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    },
  );
}

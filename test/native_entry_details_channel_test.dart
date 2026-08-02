import 'package:debt_tracker/core/platform/native_entry_details_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads a canonical ISO date and bounded progress payload', () async {
    const channel = MethodChannel('test.native.entry_details.load');
    final details = NativeEntryDetailsChannel(
      channel: channel,
      isIos: () => true,
    );
    String? loadedID;
    details.onLoadEntry = (id) async {
      loadedID = id;
      return {
        'schemaVersion': 1,
        'entry': {
          'id': id,
          'dateIso8601': '2026-08-01T00:00:00.000Z',
          'dateText': 'Aug 1, 2026',
          'progress': 1.0,
          'payments': <Map<String, dynamic>>[],
        },
      };
    };

    final response =
        await details.handleNativeCall(
              const MethodCall('loadEntry', {'id': '42'}),
            )
            as Map<String, dynamic>;

    expect(loadedID, '42');
    expect(response['entry']['dateIso8601'], '2026-08-01T00:00:00.000Z');
    expect(response['entry']['progress'], 1.0);
  });

  test('forwards every native action with its entry and payment IDs', () async {
    const channel = MethodChannel('test.native.entry_details.actions');
    final details = NativeEntryDetailsChannel(
      channel: channel,
      isIos: () => true,
    );
    final calls = <List<Object?>>[];
    details.onPerformAction = (id, action, paymentID, payment) async {
      calls.add([id, action, paymentID]);
      expect(payment, isNull);
      return <String, dynamic>{};
    };

    for (final action in [
      'edit',
      'markCompleted',
      'delete',
      'restore',
      'addPayment',
    ]) {
      await details.handleNativeCall(
        MethodCall('performAction', {'id': '42', 'action': action}),
      );
    }
    await details.handleNativeCall(
      const MethodCall('performAction', {
        'id': '42',
        'action': 'deletePayment',
        'paymentID': 3,
      }),
    );

    expect(calls, [
      ['42', 'edit', null],
      ['42', 'markCompleted', null],
      ['42', 'delete', null],
      ['42', 'restore', null],
      ['42', 'addPayment', null],
      ['42', 'deletePayment', 3],
    ]);
  });

  test(
    'top Add Payment action opens the existing sheet for the current entry',
    () async {
      const channel = MethodChannel('test.native.entry_details.add_payment');
      final details = NativeEntryDetailsChannel(
        channel: channel,
        isIos: () => true,
      );
      String? receivedID;
      String? receivedAction;
      details.onPerformAction = (id, action, paymentID, payment) async {
        receivedID = id;
        receivedAction = action;
        expect(paymentID, isNull);
        expect(payment, {
          'amount': 100.0,
          'dateIso8601': '2026-08-02T00:00:00.000Z',
          'note': 'Dinner',
        });
        return <String, dynamic>{};
      };

      await details.handleNativeCall(
        const MethodCall('performAction', {
          'id': '42',
          'action': 'addPayment',
          'amount': 100.0,
          'dateIso8601': '2026-08-02T00:00:00.000Z',
          'note': 'Dinner',
        }),
      );

      expect(receivedID, '42');
      expect(receivedAction, 'addPayment');
    },
  );
}

import 'dart:async';

import 'package:debt_tracker/core/platform/ios_navigation_channel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'native tab selections update Flutter and Flutter syncs selections back',
    () async {
      const channel = MethodChannel('test.ios.navigation.tabs');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final navigation = IosNavigationChannel(
        channel: channel,
        isIos: () => true,
      );
      var selectedIndex = 0;
      navigation.onTabSelected = (index) => selectedIndex = index;

      await navigation.handleNativeCall(
        const MethodCall('nativeTabSelected', {'index': 2}),
      );
      await navigation.setSelectedTab(selectedIndex);

      expect(selectedIndex, 2);
      expect(calls.single.method, 'setSelectedTab');
      expect(calls.single.arguments, {'index': 2});
    },
  );

  test('native Search tab is forwarded to Flutter', () async {
    const channel = MethodChannel('test.ios.navigation.search');
    final navigation = IosNavigationChannel(
      channel: channel,
      isIos: () => true,
    );
    var selectedIndex = -1;
    navigation.onTabSelected = (index) => selectedIndex = index;

    await navigation.handleNativeCall(
      const MethodCall('nativeTabSelected', {'index': 4}),
    );

    expect(selectedIndex, 4);
  });

  test('native search query and dismissal callbacks reach Flutter', () async {
    const channel = MethodChannel('test.ios.navigation.search_callbacks');
    final navigation = IosNavigationChannel(
      channel: channel,
      isIos: () => true,
    );
    String? query;
    var dismissed = false;
    navigation.onSearchQueryChanged = (value) => query = value;
    navigation.onSearchDismissed = () => dismissed = true;

    await navigation.handleNativeCall(
      const MethodCall('nativeSearchQueryChanged', 'notes'),
    );
    await navigation.handleNativeCall(
      const MethodCall('nativeSearchDismissed'),
    );

    expect(query, 'notes');
    expect(dismissed, isTrue);
  });

  test('system Search-tab activation reaches Flutter without a route', () async {
    const channel = MethodChannel('test.ios.navigation.system_search');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    final navigation = IosNavigationChannel(
      channel: channel,
      isIos: () => true,
    );
    var activated = false;
    navigation.onSearchActivated = () => activated = true;

    await navigation.handleNativeCall(
      const MethodCall('nativeSearchActivated'),
    );
    await navigation.activateSearchTab();

    expect(activated, isTrue);
    expect(calls.single.method, 'activateSearchTab');
  });

  test('rapid native add requests open one chooser at a time', () async {
    const channel = MethodChannel('test.ios.navigation.add');
    final navigation = IosNavigationChannel(
      channel: channel,
      isIos: () => true,
    );
    final completer = Completer<void>();
    var opens = 0;
    navigation.onAddRequested = () {
      opens++;
      return completer.future;
    };

    final first = navigation.handleNativeCall(const MethodCall('openAddEntry'));
    await navigation.handleNativeCall(const MethodCall('openAddEntry'));
    expect(opens, 1);

    completer.complete();
    await first;
    await navigation.handleNativeCall(const MethodCall('openAddEntry'));
    expect(opens, 2);
  });

  test(
    'rapid native settings requests open one settings route at a time',
    () async {
      const channel = MethodChannel('test.ios.navigation.settings');
      final navigation = IosNavigationChannel(
        channel: channel,
        isIos: () => true,
      );
      final completer = Completer<void>();
      var opens = 0;
      navigation.onSettingsRequested = () {
        opens++;
        return completer.future;
      };

      final first = navigation.handleNativeCall(
        const MethodCall('openSettings'),
      );
      await navigation.handleNativeCall(const MethodCall('openSettings'));
      expect(opens, 1);

      completer.complete();
      await first;
      await navigation.handleNativeCall(const MethodCall('openSettings'));
      expect(opens, 2);
    },
  );

  test('Android does not send native navigation commands', () async {
    const channel = MethodChannel('test.ios.navigation.android');
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
    final navigation = IosNavigationChannel(
      channel: channel,
      isIos: () => false,
    );

    await navigation.setSelectedTab(1);
    await navigation.setNavigationVisible(false);

    expect(calls, 0);
  });

  test(
    'pushed shell routes hide native navigation until they are popped',
    () async {
      const channel = MethodChannel('test.ios.navigation.visibility');
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(() {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final navigation = IosNavigationChannel(
        channel: channel,
        isIos: () => true,
      );
      final observer = IosNavigationRouteObserver(navigation);
      final root = MaterialPageRoute<void>(builder: (_) => const SizedBox());
      final detail = MaterialPageRoute<void>(builder: (_) => const SizedBox());

      observer.didPush(detail, root);
      await Future<void>.delayed(Duration.zero);
      observer.didPop(detail, root);
      await Future<void>.delayed(Duration.zero);

      expect(calls.map((call) => call.arguments), [
        {'visible': false},
        {'visible': true},
      ]);
    },
  );

  test('setNavigationVisible sends correct channel method arguments', () async {
    const channel = MethodChannel('test.ios.navigation.visibility_toggle');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return null;
        });
    addTearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });
    final navigation = IosNavigationChannel(
      channel: channel,
      isIos: () => true,
    );

    await navigation.setNavigationVisible(true);
    await navigation.setNavigationVisible(false);

    expect(calls.map((c) => c.method), [
      'setNavigationVisible',
      'setNavigationVisible',
    ]);
    expect(calls.map((c) => c.arguments), [
      {'visible': true},
      {'visible': false},
    ]);
  });
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

const _channelName = 'com.daftari/native_bottom_navigation';

class IosNavigationChannel {
  IosNavigationChannel({MethodChannel? channel, bool Function()? isIos})
    : _channel = channel ?? const MethodChannel(_channelName),
      _isIos = isIos ?? (() => Platform.isIOS) {
    _channel.setMethodCallHandler(handleNativeCall);
  }

  final MethodChannel _channel;
  final bool Function() _isIos;
  ValueChanged<int>? onTabSelected;
  Future<void> Function()? onAddRequested;
  bool _addRequestInProgress = false;

  Future<dynamic> handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'nativeTabSelected':
        final arguments = call.arguments;
        final index = arguments is Map ? arguments['index'] : null;
        if (index is int && index >= 0 && index < 4) {
          onTabSelected?.call(index);
        }
        return null;
      case 'openAddEntry':
        if (_addRequestInProgress || onAddRequested == null) {
          return null;
        }
        _addRequestInProgress = true;
        try {
          await onAddRequested!();
        } finally {
          _addRequestInProgress = false;
        }
        return null;
      default:
        throw MissingPluginException(
          'Unknown iOS navigation method: ${call.method}',
        );
    }
  }

  Future<void> setSelectedTab(int index) async {
    if (!_isIos()) return;
    await _channel.invokeMethod<void>('setSelectedTab', {'index': index});
  }

  Future<void> setNavigationVisible(bool visible) async {
    if (!_isIos()) return;
    await _channel.invokeMethod<void>('setNavigationVisible', {
      'visible': visible,
    });
  }
}

final iosNavigationChannel = IosNavigationChannel();

class IosNavigationRouteObserver extends NavigatorObserver {
  IosNavigationRouteObserver(this._navigation);

  final IosNavigationChannel _navigation;
  var _pushedRouteDepth = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (previousRoute != null) {
      _pushedRouteDepth++;
      unawaited(_navigation.setNavigationVisible(false));
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    if (previousRoute != null) {
      _pushedRouteDepth = _pushedRouteDepth > 0 ? _pushedRouteDepth - 1 : 0;
      unawaited(_navigation.setNavigationVisible(_pushedRouteDepth == 0));
    }
  }
}

final iosNavigationRouteObserver = IosNavigationRouteObserver(
  iosNavigationChannel,
);

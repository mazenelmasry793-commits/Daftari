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
  Future<void> Function()? onSettingsRequested;
  Future<Map<String, dynamic>> Function()? onSettingsExportRequested;
  Future<Map<String, dynamic>> Function(String contents)?
  onSettingsImportPreviewRequested;
  Future<void> Function(String contents, String strategy)?
  onSettingsImportRequested;
  Future<void> Function()? onSettingsEmptyTrashRequested;
  Future<void> Function()? onSettingsDeleteAllDataRequested;
  Future<void> Function()? onSettingsOpenTrashRequested;
  Future<Map<String, dynamic>> Function()? onTrashLoadRequested;
  Future<Map<String, dynamic>> Function(String id)? onTrashRestoreRequested;
  Future<Map<String, dynamic>> Function(String id)?
  onTrashDeleteForeverRequested;
  Future<Map<String, dynamic>> Function()? onTrashEmptyRequested;
  ValueChanged<String>? onSearchQueryChanged;
  VoidCallback? onSearchActivated;
  VoidCallback? onSearchDismissed;
  bool _addRequestInProgress = false;
  bool _settingsRequestInProgress = false;

  Future<dynamic> handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'nativeTabSelected':
        final arguments = call.arguments;
        final index = arguments is Map ? arguments['index'] : null;
        if (index is int && index >= 0 && index <= 4) {
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
      case 'openSettings':
        if (_settingsRequestInProgress || onSettingsRequested == null) {
          return null;
        }
        _settingsRequestInProgress = true;
        try {
          await onSettingsRequested!();
        } finally {
          _settingsRequestInProgress = false;
        }
        return null;
      case 'nativeSearchQueryChanged':
        final query = call.arguments as String?;
        if (query != null) onSearchQueryChanged?.call(query);
        return null;
      case 'nativeSearchActivated':
        onSearchActivated?.call();
        return null;
      case 'nativeSearchDismissed':
        onSearchDismissed?.call();
        return null;
      case 'nativeSettingsExport':
        return await onSettingsExportRequested?.call();
      case 'nativeSettingsImportPreview':
        final arguments = call.arguments;
        final contents = arguments is Map ? arguments['contents'] : null;
        if (contents is! String || onSettingsImportPreviewRequested == null) {
          return null;
        }
        return await onSettingsImportPreviewRequested!(contents);
      case 'nativeSettingsImport':
        final arguments = call.arguments;
        final contents = arguments is Map ? arguments['contents'] : null;
        final strategy = arguments is Map ? arguments['strategy'] : null;
        if (contents is String &&
            strategy is String &&
            onSettingsImportRequested != null) {
          await onSettingsImportRequested!(contents, strategy);
        }
        return null;
      case 'nativeSettingsEmptyTrash':
        await onSettingsEmptyTrashRequested?.call();
        return null;
      case 'nativeSettingsDeleteAllData':
        await onSettingsDeleteAllDataRequested?.call();
        return null;
      case 'nativeSettingsOpenTrash':
        await onSettingsOpenTrashRequested?.call();
        return null;
      case 'nativeTrashLoad':
        return await onTrashLoadRequested?.call();
      case 'nativeTrashRestore':
        final id = call.arguments is Map ? call.arguments['id'] : null;
        if (id is String && onTrashRestoreRequested != null) {
          return await onTrashRestoreRequested!(id);
        }
        return null;
      case 'nativeTrashDeleteForever':
        final id = call.arguments is Map ? call.arguments['id'] : null;
        if (id is String && onTrashDeleteForeverRequested != null) {
          return await onTrashDeleteForeverRequested!(id);
        }
        return null;
      case 'nativeTrashEmpty':
        return await onTrashEmptyRequested?.call();
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

  /// Reports whether a Flutter detail route is covering the native Home.
  /// This never controls the Apple system tab bar.
  Future<void> setFlutterDetailVisible(bool visible) async {
    if (!_isIos()) return;
    await _channel.invokeMethod<void>('setFlutterDetailVisible', {
      'visible': visible,
    });
  }

  Future<void> setSearchVisible(bool visible) async {
    if (!_isIos()) return;
    await _channel.invokeMethod<void>('setSearchVisible', {'visible': visible});
  }

  Future<void> activateSearchTab() async {
    if (!_isIos()) return;
    await _channel.invokeMethod<void>('activateSearchTab');
  }

  Future<void> restoreNativeSettings() async {
    if (!_isIos()) return;
    await _channel.invokeMethod<void>('restoreNativeSettings');
  }

  Future<void> updateNativeSearchResults(Map<String, dynamic> payload) async {
    if (!_isIos()) return;
    await _channel.invokeMethod<void>('nativeSearchResultsUpdated', payload);
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

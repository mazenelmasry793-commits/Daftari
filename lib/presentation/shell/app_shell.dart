import 'dart:async';
import 'dart:io';

import 'package:debt_tracker/core/platform/ios_navigation_channel.dart';
import 'package:debt_tracker/core/platform/app_toast_service.dart';
import 'package:debt_tracker/core/platform/native_sheets_channel.dart';
import 'package:debt_tracker/data/models/entry.dart';
import 'package:debt_tracker/features/dashboard/dashboard_screen.dart';
import 'package:debt_tracker/features/entry_form/entry_form_screen.dart';
import 'package:debt_tracker/features/owed_by_me/owed_by_me_screen.dart';
import 'package:debt_tracker/features/owed_to_me/owed_to_me_screen.dart';
import 'package:debt_tracker/features/scratchpad/scratchpad_screen.dart';
import 'package:debt_tracker/features/search/search_screen.dart';
import 'package:debt_tracker/features/settings/settings_screen.dart';
import 'package:debt_tracker/presentation/widgets/app_page_route.dart';
import 'package:debt_tracker/presentation/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  final _titles = const <String>[
    'Dashboard',
    'Owed To Me',
    'Owed By Me',
    'Scratchpad',
  ];

  @override
  void initState() {
    super.initState();
    iosNavigationChannel.onTabSelected = _selectTab;
    iosNavigationChannel.onAddRequested = _openAddFromNative;
    nativeSheetsChannel.onAddEntryTypeSelected = _handleNativeEntryType;
    nativeSheetsChannel.onNativeEntryFormSubmitted = _saveNativeEntry;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(iosNavigationChannel.setSelectedTab(_index));
      unawaited(iosNavigationChannel.setNavigationVisible(true));
    });
  }

  @override
  void dispose() {
    iosNavigationChannel.onTabSelected = null;
    iosNavigationChannel.onAddRequested = null;
    nativeSheetsChannel.onAddEntryTypeSelected = null;
    nativeSheetsChannel.onNativeEntryFormSubmitted = null;
    unawaited(iosNavigationChannel.setNavigationVisible(false));
    super.dispose();
  }

  void _openSearch() {
    Navigator.of(context).push(AppPageRoute(child: const SearchScreen()));
  }

  void _openSettings() {
    Navigator.of(context).push(AppPageRoute(child: const SettingsScreen()));
  }

  void _openForm({EntryType? initialType, Entry? entry}) {
    if (Platform.isIOS && entry == null) {
      unawaited(
        nativeSheetsChannel.showNativeEntryForm(
          type: (initialType ?? EntryType.owedToMe).name,
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: EntryFormScreen(
          initialType: initialType ?? EntryType.owedToMe,
          entry: entry,
        ),
      ),
    );
  }

  Future<void> _openAddChooser() {
    if (Platform.isIOS) {
      return nativeSheetsChannel.showAddEntryChooser();
    }
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.call_received_rounded),
                  title: const Text('Owed To Me'),
                  subtitle: const Text('Track money someone owes you.'),
                  onTap: () {
                    Navigator.pop(context);
                    _openForm(initialType: EntryType.owedToMe);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.call_made_rounded),
                  title: const Text('Owed By Me'),
                  subtitle: const Text('Track money you owe someone.'),
                  onTap: () {
                    Navigator.pop(context);
                    _openForm(initialType: EntryType.owedByMe);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.edit_document),
                  title: const Text('Scratchpad'),
                  subtitle: const Text('Quick note or rough calculation.'),
                  onTap: () {
                    Navigator.pop(context);
                    _openForm(initialType: EntryType.scratchpad);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAddFromNative() async {
    if (Platform.isIOS) {
      await nativeSheetsChannel.showAddEntryChooser();
    } else {
      await _openAddChooser();
    }
  }

  void _handleNativeEntryType(String type) {
    unawaited(nativeSheetsChannel.showNativeEntryForm(type: type));
  }

  Future<bool> _saveNativeEntry(Map<String, dynamic> payload) async {
    final type = switch (payload['type']) {
      'owedToMe' => EntryType.owedToMe,
      'owedByMe' => EntryType.owedByMe,
      'scratchpad' => EntryType.scratchpad,
      _ => null,
    };
    final title = (payload['title'] as String? ?? '').trim();
    final amountValue = payload['amount'];
    final amount = amountValue is num ? amountValue.toDouble() : null;
    final note = (payload['note'] as String? ?? '').trim();
    final debtDate = DateTime.tryParse(payload['debtDate'] as String? ?? '');

    if (type == null || title.isEmpty) return false;
    if (type != EntryType.scratchpad && (amount == null || amount <= 0)) {
      return false;
    }
    if (amount != null && amount <= 0) return false;

    try {
      final now = DateTime.now();
      final entry = Entry()
        ..id = Isar.autoIncrement
        ..title = title
        ..amount = amount
        ..note = note.isEmpty ? null : note
        ..type = type
        ..debtDate = debtDate ?? now
        ..status = EntryStatus.active
        ..createdAt = now
        ..updatedAt = now
        ..payments = <Payment>[];
      await ref.read(entryRepositoryProvider).save(entry);
      await appToastService.show('Entry saved', type: AppToastType.success);
      return true;
    } catch (error) {
      await appToastService.show(
        'Something went wrong',
        type: AppToastType.error,
      );
      return false;
    }
  }

  void _selectTab(int index) {
    if (index == 4) {
      _openSearch();
      unawaited(iosNavigationChannel.setSelectedTab(_index));
      return;
    }
    if (_index == index) return;
    setState(() => _index = index);
    unawaited(iosNavigationChannel.setSelectedTab(index));
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(appBootstrapProvider);

    return bootstrap.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (error, stack) =>
          Scaffold(body: Center(child: Text('Error: $error'))),
      data: (_) => _buildShell(context),
    );
  }

  Widget _buildShell(BuildContext context) {
    final pages = <Widget>[
      DashboardScreen(onSearch: _openSearch, onAdd: _openAddChooser),
      OwedToMeScreen(onAdd: () => _openForm(initialType: EntryType.owedToMe)),
      OwedByMeScreen(onAdd: () => _openForm(initialType: EntryType.owedByMe)),
      ScratchpadScreen(
        onAdd: () => _openForm(initialType: EntryType.scratchpad),
      ),
    ];

    final showSearch = _index == 0 || _index == 1 || _index == 2 || _index == 3;
    final useNativeIosNavigation = Platform.isIOS;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          if (showSearch)
            IconButton(
              tooltip: 'Search',
              icon: const Icon(Icons.search_rounded),
              onPressed: _openSearch,
            ),

          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_rounded),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Stack(
        children: [
          IndexedStack(index: _index, children: pages),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 16,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).colorScheme.surface,
                    Theme.of(
                      context,
                    ).colorScheme.surface.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: useNativeIosNavigation
          ? null
          : FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: useNativeIosNavigation
          ? null
          : BottomAppBar(
              shape: const CircularNotchedRectangle(),
              notchMargin: 8,
              clipBehavior: Clip.antiAlias,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavBarItem(
                    icon: Icons.dashboard_rounded,
                    isSelected: _index == 0,
                    onTap: () => _selectTab(0),
                  ),
                  _NavBarItem(
                    icon: Icons.edit_document,
                    isSelected: _index == 3,
                    onTap: () => _selectTab(3),
                  ),
                  const SizedBox(width: 48), // Space for FAB
                  _NavBarItem(
                    icon: Icons.call_received_rounded,
                    isSelected: _index == 1,
                    onTap: () => _selectTab(1),
                  ),
                  _NavBarItem(
                    icon: Icons.call_made_rounded,
                    isSelected: _index == 2,
                    onTap: () => _selectTab(2),
                  ),
                ],
              ),
            ),
      floatingActionButton: useNativeIosNavigation
          ? null
          : FloatingActionButton(
              shape: const CircleBorder(),
              elevation: 2,
              onPressed: _index == 0
                  ? _openAddChooser
                  : () => _openForm(initialType: _initialTypeForIndex(_index)),
              child: const Icon(Icons.add_rounded, size: 28),
            ),
    );
  }

  EntryType _initialTypeForIndex(int index) {
    switch (index) {
      case 1:
        return EntryType.owedToMe;
      case 2:
        return EntryType.owedByMe;
      case 3:
        return EntryType.scratchpad;
      default:
        return EntryType.owedToMe;
    }
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      iconSize: 28,
      icon: Icon(icon),
      color: isSelected
          ? scheme.primary
          : scheme.onSurfaceVariant.withValues(alpha: 0.6),
      onPressed: onTap,
    );
  }
}

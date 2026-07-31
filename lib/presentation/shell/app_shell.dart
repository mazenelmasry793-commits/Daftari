import 'dart:async';

import 'package:debt_tracker/data/models/entry.dart';
import 'package:debt_tracker/features/dashboard/dashboard_screen.dart';
import 'package:debt_tracker/features/entry_form/entry_form_screen.dart';
import 'package:debt_tracker/features/owed_by_me/owed_by_me_screen.dart';
import 'package:debt_tracker/features/owed_to_me/owed_to_me_screen.dart';
import 'package:debt_tracker/features/scratchpad/scratchpad_screen.dart';
import 'package:debt_tracker/features/search/search_screen.dart';
import 'package:debt_tracker/features/settings/settings_screen.dart';
import 'package:debt_tracker/features/trash/trash_screen.dart';
import 'package:debt_tracker/presentation/providers/security_controller.dart';
import 'package:debt_tracker/presentation/widgets/app_page_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Timer? _lockTimer;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _lockTimer?.cancel();
      _lockTimer = Timer(const Duration(minutes: 1), () {
        if (mounted) {
          ref.read(securityControllerProvider.notifier).lockSession();
        }
      });
    } else if (state == AppLifecycleState.resumed) {
      _lockTimer?.cancel();
    }
  }

  void _openSearch() {
    Navigator.of(context).push(AppPageRoute(child: const SearchScreen()));
  }

  void _openSettings() {
    Navigator.of(context).push(AppPageRoute(child: const SettingsScreen()));
  }

  void _openForm({
    EntryType? initialType,
    Entry? entry,
  }) {
    Navigator.of(context).push(
      AppPageRoute(
        child: EntryFormScreen(
          initialType: initialType ?? EntryType.owedToMe,
          entry: entry,
        ),
      ),
    );
  }

  void _openAddChooser() {
    showModalBottomSheet<void>(
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

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      DashboardScreen(
        onSearch: _openSearch,
        onAdd: _openAddChooser,
      ),
      OwedToMeScreen(
        onAdd: () => _openForm(initialType: EntryType.owedToMe),
      ),
      OwedByMeScreen(
        onAdd: () => _openForm(initialType: EntryType.owedByMe),
      ),
      ScratchpadScreen(
        onAdd: () => _openForm(initialType: EntryType.scratchpad),
      ),
    ];

    final showSearch = _index == 0 || _index == 1 || _index == 2 || _index == 3;

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
                    Theme.of(context).colorScheme.surface.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavBarItem(
              icon: Icons.dashboard_rounded,
              isSelected: _index == 0,
              onTap: () => setState(() => _index = 0),
            ),
            _NavBarItem(
              icon: Icons.edit_document,
              isSelected: _index == 3,
              onTap: () => setState(() => _index = 3),
            ),
            const SizedBox(width: 48), // Space for FAB
            _NavBarItem(
              icon: Icons.call_received_rounded,
              isSelected: _index == 1,
              onTap: () => setState(() => _index = 1),
            ),
            _NavBarItem(
              icon: Icons.call_made_rounded,
              isSelected: _index == 2,
              onTap: () => setState(() => _index = 2),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        shape: const CircleBorder(),
        elevation: 2,
        onPressed: _index == 0 ? _openAddChooser : () => _openForm(initialType: _initialTypeForIndex(_index)),
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
      color: isSelected ? scheme.primary : scheme.onSurfaceVariant.withValues(alpha: 0.6),
      onPressed: onTap,
    );
  }
}


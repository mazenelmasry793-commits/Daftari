import 'dart:async';
import 'dart:io';

import 'package:debt_tracker/core/platform/ios_navigation_channel.dart';
import 'package:debt_tracker/core/platform/native_dashboard_channel.dart';
import 'package:debt_tracker/core/platform/native_entry_details_channel.dart';
import 'package:debt_tracker/core/platform/app_toast_service.dart';
import 'package:debt_tracker/core/widgets/confirm_dialog.dart';
import 'package:debt_tracker/core/platform/native_sheets_channel.dart';
import 'package:debt_tracker/core/utils/formatters.dart';
import 'package:debt_tracker/data/models/entry.dart';
import 'package:debt_tracker/features/dashboard/dashboard_screen.dart';
import 'package:debt_tracker/features/entry_details/entry_details_screen.dart';
import 'package:debt_tracker/features/entry_form/entry_form_screen.dart';
import 'package:debt_tracker/features/entry_details/widgets/add_payment_dialog.dart';
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
  bool _searchActive = false;
  String _searchQuery = '';
  int _searchPreviousIndex = 0;
  bool _nativeDetailOpening = false;

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
    iosNavigationChannel.onSettingsRequested = _openSettings;
    iosNavigationChannel.onSearchQueryChanged = _onNativeSearchQueryChanged;
    iosNavigationChannel.onSearchActivated = _enterSearchFromNative;
    iosNavigationChannel.onSearchDismissed = _dismissSearch;
    nativeDashboardChannel.onOpenEntryDetails = _openNativeEntryDetails;
    nativeEntryDetailsChannel.onLoadEntry = _loadNativeEntryDetails;
    nativeEntryDetailsChannel.onPerformAction =
        _performNativeEntryDetailsAction;
    nativeSheetsChannel.onAddEntryTypeSelected = _handleNativeEntryType;
    nativeSheetsChannel.onNativeEntryFormSubmitted = _saveNativeEntry;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(iosNavigationChannel.setSelectedTab(_index));
      unawaited(iosNavigationChannel.setNavigationVisible(true));
      ref.read(visibleEntriesProvider).whenData((entries) {
        unawaited(nativeDashboardChannel.updateSnapshot(entries));
      });
    });
  }

  @override
  void dispose() {
    iosNavigationChannel.onTabSelected = null;
    iosNavigationChannel.onAddRequested = null;
    iosNavigationChannel.onSettingsRequested = null;
    iosNavigationChannel.onSearchQueryChanged = null;
    iosNavigationChannel.onSearchActivated = null;
    iosNavigationChannel.onSearchDismissed = null;
    nativeDashboardChannel.onOpenEntryDetails = null;
    nativeEntryDetailsChannel.onLoadEntry = null;
    nativeEntryDetailsChannel.onPerformAction = null;
    nativeSheetsChannel.onAddEntryTypeSelected = null;
    nativeSheetsChannel.onNativeEntryFormSubmitted = null;
    unawaited(iosNavigationChannel.setNavigationVisible(false));
    super.dispose();
  }

  bool _searchRouteOpening = false;

  void _openSearch() {
    if (Platform.isIOS) {
      _enterSearch();
      return;
    }
    unawaited(_pushAndroidSearch());
  }

  Future<void> _pushAndroidSearch() async {
    if (_searchRouteOpening) return;
    _searchRouteOpening = true;
    try {
      await Navigator.of(
        context,
      ).push(AppPageRoute<void>(child: const SearchScreen()));
    } finally {
      _searchRouteOpening = false;
    }
  }

  void _enterSearch() {
    if (Platform.isIOS) {
      _enterSearchFromNative();
      unawaited(iosNavigationChannel.activateSearchTab());
      return;
    }
    if (_searchActive) {
      unawaited(iosNavigationChannel.setSearchVisible(true));
      return;
    }
    _searchPreviousIndex = _index;
    setState(() {
      _searchActive = true;
      _searchQuery = '';
    });
    unawaited(iosNavigationChannel.setSearchVisible(true));
  }

  void _enterSearchFromNative() {
    if (_searchActive) return;
    _searchPreviousIndex = _index;
    setState(() {
      _searchActive = true;
      _searchQuery = '';
    });
  }

  void _onNativeSearchQueryChanged(String query) {
    if (!_searchActive) return;
    setState(() => _searchQuery = query.trim());
  }

  void _dismissSearch({int? nextIndex}) {
    if (!_searchActive) return;
    final restoredIndex = nextIndex ?? _searchPreviousIndex;
    setState(() {
      _searchActive = false;
      _searchQuery = '';
      _index = restoredIndex;
    });
    unawaited(iosNavigationChannel.setSearchVisible(false));
    unawaited(iosNavigationChannel.setSelectedTab(restoredIndex));
  }

  Future<void> _openSettings() async {
    await Navigator.of(
      context,
    ).push(AppPageRoute(child: const SettingsScreen()));
  }

  Future<void> _openNativeEntryDetails(String id) async {
    if (_nativeDetailOpening) return;
    final entryId = int.tryParse(id);
    if (entryId == null) return;
    _nativeDetailOpening = true;
    await iosNavigationChannel.setFlutterDetailVisible(true);
    if (!mounted) {
      _nativeDetailOpening = false;
      return;
    }
    try {
      await Navigator.of(
        context,
      ).push(AppPageRoute(child: EntryDetailsScreen(entryId: entryId)));
    } finally {
      if (mounted) {
        await iosNavigationChannel.setFlutterDetailVisible(false);
      }
      _nativeDetailOpening = false;
    }
  }

  Future<Map<String, dynamic>> _loadNativeEntryDetails(String id) async {
    final entry = await ref
        .read(entryRepositoryProvider)
        .getById(int.parse(id));
    return _nativeEntryDetailsResponse(entry);
  }

  Future<Map<String, dynamic>> _performNativeEntryDetailsAction(
    String id,
    String action,
    int? paymentId,
  ) async {
    final repository = ref.read(entryRepositoryProvider);
    var entry = await repository.getById(int.parse(id));
    if (entry == null) return _nativeEntryDetailsResponse(null, close: true);
    var close = false;

    try {
      switch (action) {
        case 'edit':
          final result = await showModalBottomSheet<Entry?>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            showDragHandle: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            builder: (context) => ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              child: EntryFormScreen(entry: entry!, initialType: entry.type),
            ),
          );
          if (result != null) entry = result;
        case 'markCompleted':
          await repository.markCompleted(entry.id);
          await appToastService.show(
            'Marked as completed',
            type: AppToastType.success,
          );
        case 'restore':
          await repository.restore(entry.id);
          await appToastService.show(
            'Entry restored',
            type: AppToastType.success,
          );
        case 'delete':
          final deleted = await showConfirmationDialog(
            context,
            title: entry.isDeleted ? 'Delete forever?' : 'Move to trash?',
            message: entry.isDeleted
                ? 'This permanently deletes the entry from the database.'
                : 'The entry will move to Trash and can be restored later.',
            confirmLabel: entry.isDeleted ? 'Delete Forever' : 'Move to Trash',
            destructive: true,
          );
          if (deleted) {
            if (entry.isDeleted) {
              await repository.permanentlyDelete(entry.id);
              await appToastService.show(
                'Deleted permanently',
                type: AppToastType.success,
              );
            } else {
              await repository.softDelete(entry.id);
              await appToastService.show(
                'Moved to trash',
                type: AppToastType.success,
              );
            }
            close = true;
          }
        case 'addPayment':
          final payment = await showDialog<Payment>(
            context: context,
            builder: (_) => const AddPaymentDialog(),
          );
          if (payment != null) {
            entry.payments = List.from(entry.payments)..add(payment);
            entry.updatedAt = DateTime.now();
            if (entry.remainingAmount <= 0)
              entry.status = EntryStatus.completed;
            await repository.save(entry);
            await appToastService.show(
              'Payment added',
              type: AppToastType.success,
            );
          }
        case 'deletePayment':
          if (paymentId == null ||
              paymentId < 0 ||
              paymentId >= entry.payments.length) {
            break;
          }
          final payment = entry.payments[paymentId];
          final deleted = await showConfirmationDialog(
            context,
            title: 'Delete Payment?',
            message: 'Are you sure you want to delete this payment?',
            confirmLabel: 'Delete',
            destructive: true,
          );
          if (deleted) {
            entry.payments = List.from(entry.payments)..remove(payment);
            entry.updatedAt = DateTime.now();
            if (entry.remainingAmount > 0 &&
                entry.status == EntryStatus.completed) {
              entry.status = EntryStatus.active;
            }
            await repository.save(entry);
          }
      }
      entry = await repository.getById(entry.id);
      return _nativeEntryDetailsResponse(entry, close: close);
    } catch (_) {
      await appToastService.show(
        'Something went wrong',
        type: AppToastType.error,
      );
      return _nativeEntryDetailsResponse(entry);
    }
  }

  Map<String, dynamic> _nativeEntryDetailsResponse(
    Entry? entry, {
    bool close = false,
  }) {
    if (entry == null)
      return {'schemaVersion': 1, 'close': close, 'entry': null};
    final original = entry.amount ?? 0.0;
    final paid = entry.paidAmount;
    final remaining = entry.remainingAmount;
    final progress = original <= 0 ? 0.0 : (paid / original).clamp(0.0, 1.0);
    return {
      'schemaVersion': 1,
      'close': close,
      'entry': {
        'id': entry.id.toString(),
        'title': entry.title,
        'type': entry.type.name,
        'status': entry.isDeleted
            ? 'deleted'
            : entry.status == EntryStatus.completed
            ? 'completed'
            : 'active',
        'dateText': AppFormatters.date.format(
          entry.debtDate ?? entry.createdAt,
        ),
        'dateIso8601': (entry.debtDate ?? entry.createdAt)
            .toUtc()
            .toIso8601String(),
        'note': entry.note ?? '',
        'originalText': AppFormatters.moneyValue(original),
        'paidText': AppFormatters.moneyValue(paid),
        'remainingText': AppFormatters.moneyValue(remaining),
        'progress': progress,
        'payments': [
          for (var index = 0; index < entry.payments.length; index++)
            {
              'id': index,
              'amountText': AppFormatters.moneyValue(
                entry.payments[index].amount,
              ),
              'dateText': AppFormatters.dateTime.format(
                entry.payments[index].date,
              ),
              'note': entry.payments[index].note ?? '',
            },
        ],
      },
    };
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
      _enterSearch();
      return;
    }
    if (_searchActive) {
      _dismissSearch(nextIndex: index);
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
    ref.listen(visibleEntriesProvider, (_, next) {
      next.whenData((entries) {
        unawaited(nativeDashboardChannel.updateSnapshot(entries));
      });
    });

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
      appBar: _searchActive
          ? null
          : AppBar(
              title: Text(_titles[_index]),
              actions: [
                if (showSearch && !useNativeIosNavigation)
                  IconButton(
                    tooltip: 'Search',
                    icon: const Icon(Icons.search_rounded),
                    onPressed: _openSearch,
                  ),
                if (!useNativeIosNavigation)
                  IconButton(
                    tooltip: 'Settings',
                    icon: const Icon(Icons.settings_rounded),
                    onPressed: _openSettings,
                  ),
              ],
            ),
      body: Stack(
        children: [
          if (_searchActive)
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 64, 16, 120),
                children: [SearchResultsBody(query: _searchQuery)],
              ),
            )
          else
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

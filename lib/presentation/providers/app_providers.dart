import 'package:debt_tracker/data/local/app_database.dart';
import 'package:debt_tracker/data/models/entry.dart';
import 'package:debt_tracker/data/repositories/entry_repository_factory.dart';
import 'package:debt_tracker/domain/repositories/entry_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar_community/isar.dart';

class AppBootstrap {
  const AppBootstrap({required this.isar, required this.entryRepository});

  final Isar isar;
  final EntryRepository entryRepository;
}

class DashboardTotals {
  const DashboardTotals({required this.owedToMe, required this.iOwe});

  final double owedToMe;
  final double iOwe;
}

DashboardTotals calculateDashboardTotals(Iterable<Entry> entries) {
  var owedToMe = 0.0;
  var iOwe = 0.0;

  for (final entry in entries) {
    if (entry.status != EntryStatus.active || entry.deletedAt != null) {
      continue;
    }

    final remaining = entry.remainingAmount > 0 ? entry.remainingAmount : 0.0;
    switch (entry.type) {
      case EntryType.owedToMe:
        owedToMe += remaining;
        break;
      case EntryType.owedByMe:
        iOwe += remaining;
        break;
      case EntryType.scratchpad:
        break;
    }
  }

  return DashboardTotals(owedToMe: owedToMe, iOwe: iOwe);
}

final appBootstrapProvider = FutureProvider<AppBootstrap>((ref) async {
  final isar = await AppDatabase.open();
  final entryRepository = createEntryRepository(isar: isar);
  return AppBootstrap(isar: isar, entryRepository: entryRepository);
});

final entryRepositoryProvider = Provider<EntryRepository>((ref) {
  return ref.watch(appBootstrapProvider).requireValue.entryRepository;
});

final recentEntriesProvider = StreamProvider<List<Entry>>((ref) {
  return ref.watch(entryRepositoryProvider).watchRecentEntries();
});

final dashboardOwedToMeTotalProvider = FutureProvider<double>((ref) {
  return ref.watch(entryRepositoryProvider).totalOwedToMe();
});

final dashboardIOweTotalProvider = FutureProvider<double>((ref) {
  return ref.watch(entryRepositoryProvider).totalIOwe();
});

final owedToMeEntriesProvider = StreamProvider<List<Entry>>((ref) {
  return ref
      .watch(entryRepositoryProvider)
      .watchActiveByType(EntryType.owedToMe);
});

final owedByMeEntriesProvider = StreamProvider<List<Entry>>((ref) {
  return ref
      .watch(entryRepositoryProvider)
      .watchActiveByType(EntryType.owedByMe);
});

final scratchpadEntriesProvider = StreamProvider<List<Entry>>((ref) {
  return ref
      .watch(entryRepositoryProvider)
      .watchActiveByType(EntryType.scratchpad);
});

final trashEntriesProvider = StreamProvider<List<Entry>>((ref) {
  return ref.watch(entryRepositoryProvider).watchTrash();
});

final visibleEntriesProvider = StreamProvider<List<Entry>>((ref) {
  return ref.watch(entryRepositoryProvider).watchAllVisible();
});

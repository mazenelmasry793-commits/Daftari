import 'package:debt_tracker/data/models/entry.dart';
import 'package:debt_tracker/domain/repositories/entry_repository.dart';
import 'package:debt_tracker/features/settings/settings_screen.dart';
import 'package:debt_tracker/main.dart';
import 'package:debt_tracker/presentation/providers/app_providers.dart';
import 'package:debt_tracker/presentation/shell/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('startup opens the root shell without a PIN flow', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entryRepositoryProvider.overrideWithValue(_EmptyEntryRepository()),
          appRepositoryReadyProvider.overrideWith(
            (ref) async => _EmptyEntryRepository(),
          ),
        ],
        child: const DebtTrackerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.byType(BottomAppBar), findsOneWidget);
    expect(find.byType(FloatingActionButton), findsOneWidget);
    expect(find.text('Set PIN'), findsNothing);
  });

  testWidgets('settings contain no PIN actions', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          entryRepositoryProvider.overrideWithValue(_EmptyEntryRepository()),
          appRepositoryReadyProvider.overrideWith(
            (ref) async => _EmptyEntryRepository(),
          ),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );

    expect(find.text('Security'), findsNothing);
    expect(find.text('Set PIN'), findsNothing);
    expect(find.text('Change PIN'), findsNothing);
  });
}

class _EmptyEntryRepository implements EntryRepository {
  @override
  Future<void> deleteAllData() async {}

  @override
  Future<void> emptyTrash() async {}

  @override
  Future<void> permanentlyDelete(int id) async {}

  @override
  Future<void> restore(int id) async {}

  @override
  Future<void> softDelete(int id) async {}

  @override
  Future<void> markCompleted(int id) async {}

  @override
  Future<Entry?> getById(int id) async => null;

  @override
  Future<List<Entry>> search(String query) async => const [];

  @override
  Future<Entry> save(Entry entry) async => entry;

  @override
  Future<double> totalIOwe() async => 0;

  @override
  Future<double> totalOwedToMe() async => 0;

  @override
  Stream<List<Entry>> watchActiveByType(EntryType type) =>
      Stream.value(const []);

  @override
  Stream<List<Entry>> watchAllVisible() => Stream.value(const []);

  @override
  Stream<List<Entry>> watchRecentEntries({int limit = 6}) =>
      Stream.value(const []);

  @override
  Stream<List<Entry>> watchTrash() => Stream.value(const []);

  @override
  Future<String> exportJson() async => '{}';

  @override
  Future<ImportPreview> previewImport(String jsonString) async =>
      const ImportPreview(newEntries: 0, conflictingEntries: 0);

  @override
  Future<ImportResult> importJson(
    String jsonString, {
    ImportStrategy strategy = ImportStrategy.skipExisting,
  }) async => const ImportResult(inserted: 0, replaced: 0, skipped: 0);
}

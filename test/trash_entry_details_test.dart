import 'dart:async';

import 'package:debt_tracker/data/models/entry.dart';
import 'package:debt_tracker/domain/repositories/entry_repository.dart';
import 'package:debt_tracker/features/entry_details/entry_details_screen.dart';
import 'package:debt_tracker/presentation/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deleted state uses the deletion marker with a legacy fallback', () {
    final activeInTrash = _entry(
      status: EntryStatus.active,
      deletedAt: DateTime(2026, 1, 2),
    );
    final completedInTrash = _entry(
      status: EntryStatus.completed,
      deletedAt: DateTime(2026, 1, 2),
    );
    final legacyDeleted = _entry(status: EntryStatus.deleted);

    expect(activeInTrash.isDeleted, isTrue);
    expect(completedInTrash.isDeleted, isTrue);
    expect(legacyDeleted.isDeleted, isTrue);
  });

  testWidgets('trashed details are read-only and restore preserves data', (
    tester,
  ) async {
    final entry = _entry(
      status: EntryStatus.completed,
      deletedAt: DateTime(2026, 1, 2),
      payments: [_payment(40)],
    );
    final repository = _TrashRepository(entry);

    await _pumpDetails(tester, repository, entry.id);

    expect(find.text('Restore'), findsOneWidget);
    expect(find.text('Delete Forever'), findsOneWidget);
    expect(find.text('Edit'), findsNothing);
    expect(find.text('Mark Completed'), findsNothing);
    expect(find.byIcon(Icons.add_rounded), findsNothing);
    final paymentDelete = tester.widget<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.delete_outline),
        matching: find.byType(IconButton),
      ),
    );
    expect(paymentDelete.onPressed, isNull);

    await tester.tap(find.text('Restore'));
    await tester.pumpAndSettle();

    final restored = repository.entry;
    expect(restored, isNotNull);
    expect(restored!.isDeleted, isFalse);
    expect(restored.status, EntryStatus.completed);
    expect(restored.id, entry.id);
    expect(restored.title, entry.title);
    expect(restored.amount, entry.amount);
    expect(restored.note, entry.note);
    expect(restored.createdAt, entry.createdAt);
    expect(restored.payments.single.amount, 40);
  });

  testWidgets('delete forever removes only the selected trashed entry', (
    tester,
  ) async {
    final selected = _entry(
      id: 1,
      status: EntryStatus.active,
      deletedAt: DateTime(2026, 1, 2),
    );
    final other = _entry(
      id: 2,
      status: EntryStatus.active,
      deletedAt: DateTime(2026, 1, 2),
    );
    final repository = _TrashRepository(selected, other);

    await _pumpDetails(tester, repository, selected.id);
    await tester.tap(find.text('Delete Forever'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete Forever').last);
    await tester.pumpAndSettle();

    expect(repository.entry, isNull);
    expect(repository.getStored(other.id), same(other));
  });
}

Future<void> _pumpDetails(
  WidgetTester tester,
  _TrashRepository repository,
  int entryId,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [entryRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(home: EntryDetailsScreen(entryId: entryId)),
    ),
  );
  await tester.pumpAndSettle();
}

Entry _entry({
  int id = 1,
  EntryStatus status = EntryStatus.active,
  DateTime? deletedAt,
  List<Payment> payments = const [],
}) {
  return Entry()
    ..id = id
    ..title = 'Entry $id'
    ..amount = 100
    ..note = 'Note $id'
    ..type = EntryType.owedToMe
    ..status = status
    ..createdAt = DateTime(2026, 1, 1)
    ..updatedAt = DateTime(2026, 1, 1)
    ..debtDate = DateTime(2026, 1, 1)
    ..deletedAt = deletedAt
    ..payments = payments;
}

Payment _payment(double amount) {
  return Payment()
    ..amount = amount
    ..date = DateTime(2026, 1, 1);
}

class _TrashRepository implements EntryRepository {
  _TrashRepository(Entry first, [Entry? second]) {
    _entries[first.id] = first;
    if (second != null) {
      _entries[second.id] = second;
    }
  }

  final Map<int, Entry> _entries = {};

  Entry? get entry => _entries[1];

  Entry? getStored(int id) => _entries[id];

  @override
  Future<Entry?> getById(int id) async => _entries[id];

  @override
  Future<void> restore(int id) async {
    final entry = _entries[id]!;
    if (entry.status == EntryStatus.deleted) {
      entry.status = EntryStatus.active;
    }
    entry.deletedAt = null;
  }

  @override
  Future<void> permanentlyDelete(int id) async {
    _entries.remove(id);
  }

  @override
  Future<Entry> save(Entry entry) => throw UnimplementedError();

  @override
  Future<void> deleteAllData() => throw UnimplementedError();

  @override
  Future<void> emptyTrash() => throw UnimplementedError();

  @override
  Future<String> exportJson() => throw UnimplementedError();

  @override
  Future<ImportResult> importJson(
    String jsonString, {
    ImportStrategy strategy = ImportStrategy.skipExisting,
  }) => throw UnimplementedError();

  @override
  Future<void> markCompleted(int id) => throw UnimplementedError();

  @override
  Future<ImportPreview> previewImport(String jsonString) =>
      throw UnimplementedError();

  @override
  Future<void> softDelete(int id) => throw UnimplementedError();

  @override
  Future<List<Entry>> search(String query) => throw UnimplementedError();

  @override
  Future<double> totalIOwe() => throw UnimplementedError();

  @override
  Future<double> totalOwedToMe() => throw UnimplementedError();

  @override
  Stream<List<Entry>> watchActiveByType(EntryType type) => Stream.empty();

  @override
  Stream<List<Entry>> watchAllVisible() => Stream.empty();

  @override
  Stream<List<Entry>> watchRecentEntries({int limit = 6}) => Stream.empty();

  @override
  Stream<List<Entry>> watchTrash() => Stream.empty();
}

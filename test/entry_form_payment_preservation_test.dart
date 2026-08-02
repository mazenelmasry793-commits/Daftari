import 'dart:async';

import 'package:debt_tracker/data/models/entry.dart';
import 'package:debt_tracker/domain/repositories/entry_repository.dart';
import 'package:debt_tracker/features/entry_form/entry_form_screen.dart';
import 'package:debt_tracker/presentation/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('editing an entry preserves its payment history', (tester) async {
    final repository = _RecordingEntryRepository();
    final firstPayment = Payment()
      ..amount = 25
      ..date = DateTime(2026, 1, 2)
      ..note = 'First payment';
    final secondPayment = Payment()
      ..amount = 15
      ..date = DateTime(2026, 1, 3)
      ..note = 'Second payment';
    final entry = _entry(payments: [firstPayment, secondPayment]);

    await _pumpForm(tester, repository: repository, entry: entry);
    await tester.enterText(find.byType(TextFormField).first, 'Updated title');
    await tester.tap(find.widgetWithText(FilledButton, 'Save Changes'));
    await tester.pumpAndSettle();

    final firstSaved = repository.saved;
    expect(firstSaved, isNotNull);
    expect(firstSaved!.id, entry.id);
    expect(firstSaved.title, 'Updated title');
    expect(firstSaved.payments, hasLength(2));
    expect(firstSaved.payments[0].amount, 25);
    expect(firstSaved.payments[0].date, DateTime(2026, 1, 2));
    expect(firstSaved.payments[0].note, 'First payment');
    expect(firstSaved.payments[1].amount, 15);
    expect(firstSaved.payments[1].date, DateTime(2026, 1, 3));
    expect(firstSaved.payments[1].note, 'Second payment');
    expect(firstSaved.paidAmount, 40);
    expect(firstSaved.remainingAmount, 60);

    await _pumpForm(tester, repository: repository, entry: firstSaved);
    await tester.enterText(find.byType(TextFormField).at(2), 'Updated note');
    await tester.tap(find.widgetWithText(FilledButton, 'Save Changes'));
    await tester.pumpAndSettle();

    expect(repository.saved!.payments, hasLength(2));
    expect(repository.saved!.paidAmount, 40);
    expect(repository.saved!.remainingAmount, 60);
  });

  testWidgets('creating a new entry starts without payments', (tester) async {
    final repository = _RecordingEntryRepository();

    await _pumpForm(tester, repository: repository);
    await tester.enterText(find.byType(TextFormField).first, 'New debt');
    await tester.enterText(find.byType(TextFormField).at(1), '100');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(repository.saved, isNotNull);
    expect(repository.saved!.payments, isEmpty);
  });

  testWidgets('editing cannot lower an amount below recorded payments', (
    tester,
  ) async {
    final repository = _RecordingEntryRepository();
    final entry = _entry(
      payments: [
        Payment()
          ..amount = 40
          ..date = DateTime(2026, 1, 2),
      ],
    );

    await _pumpForm(tester, repository: repository, entry: entry);
    await tester.enterText(find.byType(TextFormField).at(1), '39');
    await tester.tap(find.widgetWithText(FilledButton, 'Save Changes'));
    await tester.pump();

    expect(
      find.text('Amount cannot be less than the paid amount.'),
      findsOneWidget,
    );
    expect(repository.saved, isNull);
  });

  testWidgets('ordinary editing retains the existing entry type', (
    tester,
  ) async {
    final repository = _RecordingEntryRepository();
    final debt = _entry(type: EntryType.owedByMe, amount: 100);
    await _pumpForm(
      tester,
      repository: repository,
      entry: debt,
      initialType: EntryType.owedToMe,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save Changes'));
    await tester.pumpAndSettle();
    expect(repository.saved!.type, EntryType.owedByMe);
  });
}

Future<void> _pumpForm(
  WidgetTester tester, {
  required _RecordingEntryRepository repository,
  Entry? entry,
  EntryType initialType = EntryType.owedToMe,
  EntryType? conversionType,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [entryRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        home: _EntryFormHost(
          key: UniqueKey(),
          entry: entry,
          initialType: initialType,
          conversionType: conversionType,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _EntryFormHost extends StatefulWidget {
  const _EntryFormHost({
    required this.entry,
    required this.initialType,
    this.conversionType,
    super.key,
  });

  final Entry? entry;
  final EntryType initialType;
  final EntryType? conversionType;

  @override
  State<_EntryFormHost> createState() => _EntryFormHostState();
}

class _EntryFormHostState extends State<_EntryFormHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EntryFormScreen(
            initialType: widget.initialType,
            entry: widget.entry,
            conversionType: widget.conversionType,
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold();
}

Entry _entry({
  EntryType type = EntryType.owedToMe,
  double? amount = 100,
  List<Payment> payments = const [],
}) {
  return Entry()
    ..id = 42
    ..title = 'Original title'
    ..amount = amount
    ..note = 'Original note'
    ..type = type
    ..status = EntryStatus.active
    ..createdAt = DateTime(2026, 1, 1)
    ..updatedAt = DateTime(2026, 1, 1)
    ..debtDate = DateTime(2026, 1, 1)
    ..payments = payments;
}

class _RecordingEntryRepository implements EntryRepository {
  Entry? saved;
  final Map<int, Entry> _entriesById = {};

  List<Entry> get entries => _entriesById.values.toList();

  @override
  Future<Entry> save(Entry entry) async {
    saved = entry;
    _entriesById[entry.id] = entry;
    return entry;
  }

  @override
  Future<void> deleteAllData() => throw UnimplementedError();

  @override
  Future<void> emptyTrash() => throw UnimplementedError();

  @override
  Future<String> exportJson() => throw UnimplementedError();

  @override
  Future<Entry?> getById(int id) => throw UnimplementedError();

  @override
  Future<ImportResult> importJson(
    String jsonString, {
    ImportStrategy strategy = ImportStrategy.skipExisting,
  }) => throw UnimplementedError();

  @override
  Future<void> markCompleted(int id) => throw UnimplementedError();

  @override
  Future<void> permanentlyDelete(int id) => throw UnimplementedError();

  @override
  Future<ImportPreview> previewImport(String jsonString) =>
      throw UnimplementedError();

  @override
  Future<void> restore(int id) => throw UnimplementedError();

  @override
  Future<List<Entry>> search(String query) => throw UnimplementedError();

  @override
  Future<void> softDelete(int id) => throw UnimplementedError();

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

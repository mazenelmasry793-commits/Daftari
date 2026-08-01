import 'package:debt_tracker/data/models/entry.dart';
import 'package:debt_tracker/features/dashboard/dashboard_screen.dart';
import 'package:debt_tracker/features/dashboard/widgets/recent_entry_row.dart';
import 'package:debt_tracker/presentation/providers/app_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dashboard renders the grouped empty state', (tester) async {
    await tester.pumpWidget(_dashboard(const []));
    await tester.pump();

    expect(find.text('Recent Entries'), findsOneWidget);
    expect(find.text('0 items'), findsOneWidget);
    expect(find.text('No recent entries yet'), findsOneWidget);
  });

  testWidgets('dashboard pluralizes one recent entry and keeps it tappable', (
    tester,
  ) async {
    final entry = _entry('Bello', EntryType.owedToMe, 2334);
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: RecentEntryRow(entry: entry, onTap: () => tapped = true),
      ),
    );
    await tester.tap(find.byType(RecentEntryRow));

    expect(tapped, isTrue);

    await tester.pumpWidget(_dashboard([entry]));
    await tester.pump();
    expect(find.text('1 item'), findsOneWidget);
    expect(find.text('To Me'), findsOneWidget);
  });

  testWidgets('dashboard handles large amounts on a narrow, scaled viewport', (
    tester,
  ) async {
    tester.view
      ..physicalSize = const Size(640, 1400)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    final entries = [
      _entry(
        'A very long person name that should truncate',
        EntryType.owedToMe,
        987654321.99,
      ),
      _entry('Another long entry title', EntryType.owedByMe, 123456789.12),
    ];
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
        child: _dashboard(entries),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('2 items'), findsOneWidget);
    expect(find.byType(RecentEntryRow), findsNWidgets(2));
  });
}

Widget _dashboard(List<Entry> entries) {
  return ProviderScope(
    overrides: [
      visibleEntriesProvider.overrideWith((ref) => Stream.value(entries)),
    ],
    child: const MaterialApp(
      home: DashboardScreen(onSearch: _noop, onAdd: _noop),
    ),
  );
}

void _noop() {}

Entry _entry(String title, EntryType type, double amount) {
  final now = DateTime(2026, 8, 1);
  return Entry()
    ..id = title.hashCode
    ..title = title
    ..amount = amount
    ..type = type
    ..status = EntryStatus.active
    ..createdAt = now
    ..updatedAt = now
    ..debtDate = now;
}

import 'package:debt_tracker/data/models/entry.dart';
import 'package:debt_tracker/presentation/providers/app_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('calculates outstanding dashboard totals from remaining balances', () {
    final totals = calculateDashboardTotals([
      _entry(id: 1, type: EntryType.owedToMe, amount: 1000),
      _entry(
        id: 2,
        type: EntryType.owedToMe,
        amount: 1000,
        payments: [_payment(400)],
      ),
      _entry(
        id: 3,
        type: EntryType.owedToMe,
        amount: 1000,
        payments: [_payment(400), _payment(600)],
      ),
      _entry(
        id: 4,
        type: EntryType.owedByMe,
        amount: 500,
        payments: [_payment(125), _payment(75)],
      ),
    ]);

    expect(totals.owedToMe, 1600);
    expect(totals.iOwe, 300);
  });

  test('excludes deleted, completed, and scratchpad entries', () {
    final totals = calculateDashboardTotals([
      _entry(
        id: 1,
        type: EntryType.owedToMe,
        amount: 100,
        deletedAt: DateTime(2026, 1, 2),
      ),
      _entry(
        id: 2,
        type: EntryType.owedToMe,
        amount: 100,
        status: EntryStatus.completed,
      ),
      _entry(id: 3, type: EntryType.scratchpad, amount: 100),
    ]);

    expect(totals.owedToMe, 0);
    expect(totals.iOwe, 0);
  });

  test('never includes a negative contribution from legacy overpayments', () {
    final entries = [
      _entry(
        id: 1,
        type: EntryType.owedToMe,
        amount: 100,
        payments: [_payment(125)],
      ),
      _entry(id: 2, type: EntryType.owedToMe, amount: 50),
    ];

    final first = calculateDashboardTotals(entries);
    final refreshed = calculateDashboardTotals(entries);

    expect(first.owedToMe, 50);
    expect(refreshed.owedToMe, first.owedToMe);
  });
}

Entry _entry({
  required int id,
  required EntryType type,
  required double amount,
  EntryStatus status = EntryStatus.active,
  DateTime? deletedAt,
  List<Payment> payments = const [],
}) {
  return Entry()
    ..id = id
    ..title = 'Entry $id'
    ..amount = amount
    ..type = type
    ..status = status
    ..createdAt = DateTime(2026, 1, 1)
    ..updatedAt = DateTime(2026, 1, 1)
    ..deletedAt = deletedAt
    ..payments = payments;
}

Payment _payment(double amount) {
  return Payment()
    ..amount = amount
    ..date = DateTime(2026, 1, 1);
}

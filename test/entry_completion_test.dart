import 'package:debt_tracker/data/models/entry.dart';
import 'package:debt_tracker/presentation/providers/app_providers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('completion adds one final payment for an unpaid debt', () {
    final entry = _debt(amount: 1000);
    final completedAt = DateTime(2026, 1, 2, 3, 4);

    final changed = entry.markCompleted(completedAt: completedAt);

    expect(changed, isTrue);
    expect(entry.status, EntryStatus.completed);
    expect(entry.payments, hasLength(1));
    expect(entry.payments.single.amount, 1000);
    expect(entry.payments.single.date, completedAt);
    expect(entry.payments.single.note, 'Auto-filled on completion');
    expect(entry.paidAmount, 1000);
    expect(entry.remainingAmount, 0);
    expect(calculateDashboardTotals([entry]).owedToMe, 0);
  });

  test('completion preserves partial payments and adds only the balance', () {
    final firstPayment = _payment(400, DateTime(2026, 1, 1));
    final secondPayment = _payment(100, DateTime(2026, 1, 2));
    final entry = _debt(amount: 1000, payments: [firstPayment, secondPayment]);

    entry.markCompleted(completedAt: DateTime(2026, 1, 3));

    expect(entry.payments, hasLength(3));
    expect(entry.payments[0], same(firstPayment));
    expect(entry.payments[1], same(secondPayment));
    expect(entry.payments[2].amount, 500);
    expect(entry.paidAmount, 1000);
    expect(entry.remainingAmount, 0);
  });

  test('completion is idempotent and does not add zero payments', () {
    final fullyPaid = _debt(
      amount: 100,
      payments: [_payment(100, DateTime(2026, 1, 1))],
    );
    final completedAt = DateTime(2026, 1, 2);

    expect(fullyPaid.markCompleted(completedAt: completedAt), isTrue);
    expect(fullyPaid.status, EntryStatus.completed);
    expect(fullyPaid.payments, hasLength(1));
    expect(fullyPaid.markCompleted(completedAt: DateTime(2026, 1, 3)), isFalse);
    expect(fullyPaid.payments, hasLength(1));
    expect(fullyPaid.updatedAt, completedAt);
  });

  test(
    'completion safely handles overpaid, deleted, and scratchpad entries',
    () {
      final overpaid = _debt(
        amount: 100,
        payments: [_payment(125, DateTime(2026, 1, 1))],
      );
      final deleted = _debt(amount: 100, deletedAt: DateTime(2026, 1, 1));
      final scratchpad = _debt(amount: 100, type: EntryType.scratchpad);

      expect(overpaid.markCompleted(completedAt: DateTime(2026, 1, 2)), isTrue);
      expect(overpaid.status, EntryStatus.completed);
      expect(overpaid.payments, hasLength(1));
      expect(deleted.markCompleted(completedAt: DateTime(2026, 1, 2)), isFalse);
      expect(deleted.status, EntryStatus.active);
      expect(
        scratchpad.markCompleted(completedAt: DateTime(2026, 1, 2)),
        isFalse,
      );
      expect(scratchpad.status, EntryStatus.active);
    },
  );

  test(
    'completed entries retain payment history through backup serialization',
    () {
      final entry = _debt(
        amount: 1000,
        payments: [_payment(400, DateTime(2026, 1, 1))],
      );
      entry.markCompleted(completedAt: DateTime(2026, 1, 2));

      final restored = entryFromJson(entry.toJson());

      expect(restored.status, EntryStatus.completed);
      expect(restored.payments, hasLength(2));
      expect(restored.paidAmount, 1000);
      expect(restored.remainingAmount, 0);
    },
  );
}

Entry _debt({
  double amount = 100,
  EntryType type = EntryType.owedToMe,
  DateTime? deletedAt,
  List<Payment> payments = const [],
}) {
  return Entry()
    ..id = 1
    ..title = 'Debt'
    ..amount = amount
    ..type = type
    ..status = EntryStatus.active
    ..createdAt = DateTime(2026, 1, 1)
    ..updatedAt = DateTime(2026, 1, 1)
    ..debtDate = DateTime(2026, 1, 1)
    ..deletedAt = deletedAt
    ..payments = payments;
}

Payment _payment(double amount, DateTime date) {
  return Payment()
    ..amount = amount
    ..date = date;
}

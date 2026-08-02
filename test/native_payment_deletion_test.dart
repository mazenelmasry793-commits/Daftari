import 'package:debt_tracker/data/models/entry.dart';
import 'package:debt_tracker/presentation/shell/app_shell.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('valid native payment index removes exactly one payment', () {
    final entry = _entry(
      amount: 100,
      payments: [_payment(25), _payment(30), _payment(10)],
    );

    expect(removeNativePaymentAtIndex(entry, 1), isTrue);
    expect(entry.payments, hasLength(2));
    expect(entry.payments.map((payment) => payment.amount), [25, 10]);
  });

  test('invalid native payment index reports failure without mutation', () {
    final entry = _entry(amount: 100, payments: [_payment(25)]);

    expect(removeNativePaymentAtIndex(entry, 2), isFalse);
    expect(entry.payments, hasLength(1));
  });

  test('deleting from a completed entry restores active status when balance remains', () {
    final entry = _entry(
      amount: 100,
      payments: [_payment(100)],
    )..status = EntryStatus.completed;

    expect(removeNativePaymentAtIndex(entry, 0), isTrue);
    expect(entry.status, EntryStatus.active);
    expect(entry.remainingAmount, 100);
  });
}

Entry _entry({required double amount, required List<Payment> payments}) {
  final now = DateTime(2026, 8, 2);
  return Entry()
    ..id = 1
    ..title = 'Romeo'
    ..amount = amount
    ..type = EntryType.owedToMe
    ..status = EntryStatus.active
    ..debtDate = now
    ..createdAt = now
    ..updatedAt = now
    ..payments = payments;
}

Payment _payment(double amount) {
  return Payment()
    ..amount = amount
    ..date = DateTime(2026, 8, 2);
}

import 'package:debt_tracker/core/platform/native_entry_type.dart';
import 'package:debt_tracker/data/models/entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps debt types to native wire values', () {
    expect(entryTypeToNativeWireValue(EntryType.owedToMe), 'owedToMe');
    expect(entryTypeToNativeWireValue(EntryType.owedByMe), 'owedByMe');
  });

  test('rejects legacy Scratchpad values from native UI payloads', () {
    expect(
      () => entryTypeToNativeWireValue(EntryType.scratchpad),
      throwsStateError,
    );
  });
}

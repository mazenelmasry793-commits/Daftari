import 'package:debt_tracker/core/platform/native_note_details_channel.dart';
import 'package:debt_tracker/data/models/entry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'native note payload includes the canonical epoch date and fallback',
    () {
      final date = DateTime(2026, 8, 2);
      final entry = Entry()
        ..id = 7
        ..title = 'Holly'
        ..note = 'Scratchpad content'
        ..type = EntryType.scratchpad
        ..status = EntryStatus.active
        ..createdAt = date
        ..updatedAt = date
        ..debtDate = date;

      final payload = nativeNoteDetailsEntryPayload(entry);

      expect(payload['dateEpochMs'], date.millisecondsSinceEpoch);
      expect(payload['dateIso8601'], isNotEmpty);
      expect(payload['dateText'], isNotEmpty);
    },
  );
}

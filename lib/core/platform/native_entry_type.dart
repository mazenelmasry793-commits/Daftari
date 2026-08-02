import 'package:debt_tracker/data/models/entry.dart';

/// Maps persistence enum values to the camelCase values used by native UI.
String entryTypeToNativeWireValue(EntryType type) {
  return switch (type) {
    EntryType.owedToMe => 'owedToMe',
    EntryType.owedByMe => 'owedByMe',
    EntryType.scratchpad => throw StateError(
        'Legacy Scratchpad entries must not reach active native UI payloads.',
      ),
  };
}

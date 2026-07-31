import 'package:isar_community/isar.dart';

import 'entry_repository_impl.dart' as impl;

import 'package:debt_tracker/domain/repositories/entry_repository.dart';

EntryRepository createEntryRepository({required Isar isar}) {
  return impl.createEntryRepository(isar: isar);
}

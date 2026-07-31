import 'package:isar_community/isar.dart';

import 'entry_repository_impl.dart'
    if (dart.library.html) 'entry_repository_web.dart' as impl;

import 'package:debt_tracker/domain/repositories/entry_repository.dart';

EntryRepository createEntryRepository({Isar? isar}) {
  return impl.createEntryRepository(isar: isar);
}

import 'package:debt_tracker/data/models/entry.dart';
import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

class AppDatabase {
  const AppDatabase._();

  static Future<Isar> open() async {
    if (kIsWeb) {
      throw UnsupportedError('AppDatabase.open() is only used on native platforms.');
    }

    final directory = await getApplicationDocumentsDirectory();
    return Isar.open(
      [EntrySchema],
      directory: '${directory.path}/debt_tracker_db',
    );
  }
}

import 'dart:io';

import 'package:debt_tracker/data/models/entry.dart';
import 'package:isar_community/isar.dart';
import 'package:path_provider/path_provider.dart';

class AppDatabase {
  const AppDatabase._();

  static Future<Isar> open() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final databaseDirectory = Directory(
      '${documentsDirectory.path}/debt_tracker_db',
    );
    await databaseDirectory.create(recursive: true);

    return Isar.open([EntrySchema], directory: databaseDirectory.path);
  }
}

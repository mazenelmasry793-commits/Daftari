import 'dart:io';

import 'package:path_provider/path_provider.dart';

Future<String> saveTextFilePlatform({
  required String fileName,
  required String content,
}) async {
  final directory = await getApplicationDocumentsDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsString(content);
  return file.path;
}


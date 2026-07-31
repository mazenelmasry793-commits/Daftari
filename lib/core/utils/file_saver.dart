import 'file_saver_io.dart'
    if (dart.library.html) 'file_saver_web.dart';

export 'file_saver_io.dart' if (dart.library.html) 'file_saver_web.dart';

Future<String> saveTextFile({
  required String fileName,
  required String content,
}) {
  return saveTextFilePlatform(
    fileName: fileName,
    content: content,
  );
}


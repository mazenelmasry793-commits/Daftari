import 'file_saver_io.dart';

Future<String> saveTextFile({
  required String fileName,
  required String content,
}) {
  return saveTextFilePlatform(
    fileName: fileName,
    content: content,
  );
}

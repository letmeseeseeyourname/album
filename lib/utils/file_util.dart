import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<Directory> getSafeLibraryDir() async {
  if (Platform.isAndroid) {
    // Android 上用 getTemporaryDirectory 代替
    return await getTemporaryDirectory();
  } else {
    return await getLibraryDirectory();
  }
}

import 'dart:io';
import 'dart:convert';
import 'dart:mirrors';
import 'package:path/path.dart';

import '../constants/values.dart' as vc;

class FileSystem {
  // Getting project folder using introspection instead of Platform.script
  // so that it works with unit testing as well
  static String get projectFolder {
    final utils =
        dirname((reflectClass(FileSystem).owner as LibraryMirror).uri.path);
    return Directory.fromUri(Uri.parse(utils)).absolute.parent.parent.path;
  }

  static String get issuersFile {
    return join(projectFolder, vc.ASSETS, 'issuers.json');
  }

  static String get privateKeyFile {
    return join(
      projectFolder,
      vc.ASSETS,
      vc.KEYS,
      vc.PRIVATE_KEY_FILE,
    );
  }

  static String get applePrivateKeyFile {
    return join(
      projectFolder,
      vc.ASSETS,
      vc.KEYS,
      vc.APPLE_PRIVATE_KEY_FILE,
    );
  }

  static Map<String, dynamic> get issuerData {
    final issuersFile = File(FileSystem.issuersFile);
    return jsonDecode(issuersFile.readAsStringSync());
  }

  static String get publicKeyFile {
    return join(
      projectFolder,
      vc.ASSETS,
      vc.KEYS,
      vc.PUBLIC_KEY_FILE,
    );
  }

  static String get authHtmlFolder {
    return join(
      projectFolder,
      vc.ASSETS,
      vc.HTML,
    );
  }
}

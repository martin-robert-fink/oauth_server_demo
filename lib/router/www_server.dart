import 'dart:io';
import 'package:path/path.dart';

import '../utilities/file_system.dart';

import '../constants/html.dart' as hc;

/// This is a simple WWW server that will respond to a root
/// get request and display a default web page.  It will also
/// serve the success/fail auth redirects for Linux/Windows
class WwwServer {
  Future<void> serve(HttpRequest request) async {
    var path = request.uri.path;
    request.response.headers.contentType = (path.endsWith(hc.CSS))
        ? ContentType(hc.CONTENT_TEXT, hc.CONTENT_CSS)
        : ContentType(hc.CONTENT_TEXT, hc.CONTENT_HTML);
    var contentFilePath = (path == hc.ROOT) ? hc.INDEX_HTML : path.substring(1);
    var contentFile = File(join(FileSystem.authHtmlFolder, contentFilePath));
    request.response.statusCode = HttpStatus.ok;
    if (!contentFile.existsSync()) {
      request.response.statusCode = HttpStatus.notFound;
      contentFile = File(join(FileSystem.authHtmlFolder, hc.NOT_FOUND));
    }
    await request.response.addStream(contentFile.openRead());
  }

  Future<void> testServe(HttpRequest request) async {
    var path = request.uri.path;
    print(path);
    await request.response.flush();
    await request.response.close();
  }
}

import 'dart:io';

import 'www_server.dart';
import 'api_method_router.dart';
import 'auth_method_router.dart';

import '../constants/hosts.dart';

/// Parses the host rquest header and sends the request to the right
/// method router
class HostRouter {
  final _api_method_router = ApiMethodRouter();
  final _www_server = WwwServer();
  final _auth_method_router = AuthMethodRouter();

  Future<void> route(HttpServer httpsServer) async {
    await for (HttpRequest request in httpsServer) {
      /*
      print('================== Request Received ================');
      print('Host: ${request.headers.host}');
      print('Remote: ${request.connectionInfo.remoteAddress.address}');
      print('URI: ${request.uri}');
      print('Headers: ${request.headers}');
      print('====================================================');
      */
      switch (request.headers.host) {
        case WWW_HOST:
        case DOMAIN_HOST:
          await _www_server.serve(request).catchError((error, stacktrace) =>
              hostError(request.headers.host, error, stacktrace));
          break;
        case API_HOST:
          await _api_method_router.route(request).catchError(
              (error, stacktrace) =>
                  hostError(request.headers.host, error, stacktrace));
          break;
        case AUTH_HOST:
          await _auth_method_router.route(request).catchError(
              (error, stacktrace) =>
                  hostError(request.headers.host, error, stacktrace));
          break;
        default:
          request.response.statusCode = HttpStatus.notAcceptable;
          break;
      }
      await request.response.flush();
      await request.response.close();
    }
  }

  void hostError(String host, dynamic error, dynamic stacktrace) {
    print('$host route error: $error');
    print('Stracktrace: $stacktrace');
  }
}

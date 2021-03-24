import 'dart:io';

import 'api_get_router.dart';
import 'api_post_router.dart';
import 'api_delete_router.dart';

import '../constants/methods.dart' as mc;

/// The API MethodRouter takes the incoming requests and sends GET and POST
/// requests to the correct router for processing
class ApiMethodRouter {
  final _apiGetRouter = ApiGetRouter();
  final _apiPostRouter = ApiPostRouter();
  final _apiDeleteRouter = ApiDeleteRouter();

  /// Main API router functon to parse and direct the right methods (GET/POST)
  /// to the right place
  Future<void> route(HttpRequest request) async {
    switch (request.method) {
      case mc.GET:
        await _apiGetRouter.route(request).catchError((error, stacktrace) =>
            apiMethodError(request.method, error, stacktrace));
        break;
      case mc.POST:
        await _apiPostRouter.route(request).catchError((error, stacktrace) =>
            apiMethodError(request.method, error, stacktrace));
        break;
      case mc.DELETE:
        await _apiDeleteRouter.route(request).catchError((error, stacktrace) =>
            apiMethodError(request.method, error, stacktrace));
        break;
      default:
        request.response.statusCode = HttpStatus.methodNotAllowed;
    }
  }

  void apiMethodError(String method, dynamic error, dynamic stacktrace) {
    print('API $method route error: $error');
    print('Stacktrace: $stacktrace');
  }
}

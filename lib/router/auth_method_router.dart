import 'dart:io';

import 'auth_get_router.dart';
import 'auth_post_router.dart';

import '../constants/methods.dart' as mc;

/// The auth MethodRouter takes the incoming requests and sends GET and POST
/// requests to the correct router for processing
class AuthMethodRouter {
  final _authGetRouter = AuthGetRouter();
  final _authPostRouter = AuthPostRouter();

  Future<void> route(HttpRequest request) async {
    switch (request.method) {
      case mc.GET:
        await _authGetRouter.route(request).catchError((error, stacktrace) =>
            authMethodError(request.method, error, stacktrace));
        break;
      case mc.POST:
        await _authPostRouter.route(request).catchError((error, stacktrace) =>
            authMethodError(request.method, error, stacktrace));
        break;
      default:
        request.response.statusCode = HttpStatus.methodNotAllowed;
    }
  }

  void authMethodError(String method, dynamic error, dynamic stacktrace) {
    print('Auth $method route error: $error');
    print('Stacktrace: $stacktrace');
  }
}

import 'dart:io';

import 'auth_get_router.dart';

import '../auth/apple_auth.dart';
import '../auth/facebook_auth.dart';

import '../constants/paths.dart' as pc;
import '../constants/issuers.dart';

/// Routes POST requests
class AuthPostRouter {
  final _authGetRouter = AuthGetRouter();

  /// Main router function for all POST requests
  Future<void> route(HttpRequest request) async {
    request.response.statusCode = HttpStatus.badRequest;
    if (request.uri.pathSegments.length < 2) return;
    switch (request.uri.pathSegments[1]) {
      case pc.TEST:
        request.response.statusCode = HttpStatus.ok;
        break;
      case pc.AUTH:
        // Apple sends a post, but all the code to process auth redirects
        // from issuers is in GET side of the router
        await _authGetRouter.route(request);
        break;
      case pc.REVOKE:
        // Only Apple and Facebook support server-to-server notification of
        // token revocation.  These methods will put the token on a blacklist
        // so that any future attempt at using that token will be rejected.
        switch (request.uri.pathSegments.last) {
          case FACEBOOK:
            await FacebookAuth.revoke(request);
            break;
          case APPLE:
            await AppleAuth.revoke(request);
            break;
        }
        break;
      default:
        request.response.statusCode = HttpStatus.badRequest;
        break;
    }
  }
}

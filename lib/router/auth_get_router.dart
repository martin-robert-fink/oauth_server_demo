import 'dart:io';

import '../auth/social_auth.dart';
import '../auth/apple_auth.dart';
import '../auth/facebook_auth.dart';
import '../auth/github_auth.dart';
import '../auth/google_auth.dart';

import '../constants/paths.dart' as pc;
import '../constants/issuers.dart';

/// Router for auth GET requests
class AuthGetRouter {
  /// Main router function for all GET requests and the POST request from
  /// Apple that is sent here from the POST router
  Future<void> route(HttpRequest request) async {
    request.response.statusCode = HttpStatus.badRequest;
    if (request.uri.pathSegments.length < 2) return;
    switch (request.uri.pathSegments[1]) {
      case pc.TEST:
        request.response.statusCode = HttpStatus.ok;
        break;
      case pc.AUTH:
      case pc.REFRESH:
        await _v1Auth(request);
        break;
      case pc.CLIENT_ID:
        SocialAuth.clientId(request);
        break;
      default:
        request.response.statusCode = HttpStatus.badRequest;
        break;
    }
  }

  // The v1Auth redirect URI is called by the supported issuers.
  // A code will cause a request for an access token.  An access_token
  // will be sent back to the requesting client
  Future<void> _v1Auth(HttpRequest request) async {
    var auth;
    switch (request.uri.pathSegments.last.toLowerCase()) {
      case GOOGLE:
        auth = GoogleAuth();
        break;
      case GITHUB:
        auth = GithubAuth();
        break;
      case APPLE:
        auth = AppleAuth();
        break;
      case FACEBOOK:
        auth = FacebookAuth();
        break;
    }
    (request.uri.pathSegments[1] == pc.AUTH)
        ? await auth.authenticate(request)
        : await auth.refreshToken(request);
  }
}

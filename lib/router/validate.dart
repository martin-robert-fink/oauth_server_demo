import 'dart:convert';
import 'dart:io';
import '../auth/id_token.dart';

import '../constants/keys.dart' as kc;
import '../constants/values.dart' as vc;
import '../constants/errors.dart' as ec;
import '../constants/issuers.dart';

/// A holder class for the static function that checks in an incoming
/// request is valid.
class Validate {
  /// Static function that verifies the [request] to make sure it can
  /// be processed
  static Future<bool> isRequestValid(HttpRequest request) async {
    // Checks for valid Authorization header (Bearer IdToken)
    request.response.statusCode = HttpStatus.unauthorized;
    final authHeader = request.headers[HttpHeaders.authorizationHeader];
    if (authHeader == null || authHeader.isEmpty) {
      request.response.write(jsonEncode({kc.ERROR: ec.NO_AUTH_HEADER}));
      return false;
    }
    if (authHeader.first.split(' ').length != 2) {
      request.response.write(jsonEncode({kc.ERROR: ec.BAD_AUTH_HEADER}));
      return false;
    }
    // Check authorization header contains Bearer in any case
    var bearer = authHeader.first.split(' ').first.toLowerCase();
    if (bearer != vc.BEARER.trim().toLowerCase()) {
      request.response.write(jsonEncode({kc.ERROR: ec.BAD_AUTH_HEADER}));
      return false;
    }
    // Checks for issuer header and issuer is valid
    final issuer = request.headers[kc.ISSUER];
    if (issuer == null || !ISSUERS.contains(issuer.first)) {
      request.response.write(jsonEncode({kc.ERROR: ec.BAD_ISSUER_HEADER}));
      return false;
    }
    // Checks that IdToken is valid
    final idToken = authHeader.first.split(' ').last;
    if (idToken.split('.').length != 3) {
      request.response.write(jsonEncode({kc.ERROR: ec.BAD_ID_TOKEN}));
      return false;
    }
    var tokenValidation = await IdToken.validate(idToken);
    if (!tokenValidation.containsKey(kc.EMAIL)) {
      request.response.write(jsonEncode(tokenValidation));
      return false;
    }
    return true;
  }
}

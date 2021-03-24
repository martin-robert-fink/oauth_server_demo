import 'dart:io';
import 'dart:convert';

import 'package:http/http.dart';

import '../utilities/file_system.dart';
import '../database/blacklist_collection.dart';

import './social_auth.dart';

import '../constants/keys.dart' as kc;
import '../constants/values.dart' as vc;
import '../constants/issuers.dart';

/// Class [FacebookAuth] provides the overrides that are specific to the
/// Facebook authentication process.  Facebook does not provide OpenID Connect
/// ID Tokens, so an ID Token is created by the app.  ID Tokens and not
/// access_tokens are used for API authentication.
class FacebookAuth extends SocialAuth {
  @override
  String get issuer => FACEBOOK;

  /// Facebook allows user data to be retreived at will from the profile
  /// endpoint
  @override
  Future<Map<String, dynamic>> addUserData(
      Map<String, dynamic> tokenData) async {
    var response = await Client().get(
      Uri.parse(FileSystem.issuerData[issuer][kc.PROFILE_ENDPOINT]),
      headers: {
        HttpHeaders.acceptHeader: vc.APPLICATION_JSON,
        HttpHeaders.authorizationHeader: vc.BEARER + tokenData[kc.ACCESS_TOKEN],
      },
    );
    var userData = jsonDecode(response.body);
    tokenData.addAll({
      kc.NAME: userData[kc.NAME],
      kc.EMAIL: userData[kc.EMAIL],
      kc.SUB: userData[kc.SUB_ID],
    });
    var nameParts = userData[kc.NAME].split(' ');
    if (nameParts.length > 1) tokenData[kc.LAST_NAME] = nameParts.last;
    if (nameParts.length > 0) tokenData[kc.FIRST_NAME] = nameParts.first;
    return tokenData;
  }

  /// The URL construction for getting a refresh token from Facebook is unique.
  /// Also, Facebook doesn't use refresh tokens per se, bur rather long lived
  /// access tokens.  For consistency with other providers, the access token is
  /// sent as a refresh token from the client.
  @override
  String get refreshUrl {
    final refreshToken = req.headers[kc.REFRESH_TOKEN].first;
    final refreshEndpoint = FileSystem.issuerData[issuer][kc.REFRESH_ENDPOINT];
    final clientId = FileSystem.issuerData[issuer][kc.CLIENT_ID];
    final clientSecret = FileSystem.issuerData[issuer][kc.CLIENT_SECRET];
    return '$refreshEndpoint'
        '?${kc.CLIENT_ID}=$clientId'
        '&${kc.CLIENT_SECRET}=$clientSecret'
        '&${kc.FB_EXCHANGE_TOKEN}=$refreshToken'
        '&${kc.GRANT_TYPE}=${kc.FB_EXCHANGE_TOKEN}';
  }

  /// Facebook uses GET and no headers to request the new access token
  @override
  Future<Response> getRefreshToken() async {
    return await Client().get(Uri.parse(refreshUrl));
  }

  /// Since Facebook doesn't use refresh tokens, we have to assign the
  /// access_token to the refresh token field.  This is done for consistency
  /// with the other issuers.
  @override
  Map<String, dynamic> addRefreshTokenData(Map<String, dynamic> tokenData) {
    tokenData.addAll({
      kc.ISSUER: issuer,
      kc.REFRESH_TOKEN: tokenData[kc.ACCESS_TOKEN],
    });
    return tokenData;
  }

  /// Facebook supports token revocation through server to server
  /// notification.  Ironically, facebook sends back a query parameter
  /// called signed_request, but it's actually a 2-part unsigned requrest
  /// which needs to be manually base64 decoded.
  /// The user_id is then stored in the blacklist to ensure the token
  /// can never be reused.
  static Future<void> revoke(HttpRequest request) async {
    var postBody = await utf8.decoder.bind(request).join();
    var uri = Uri(query: postBody);
    var jwt = uri.queryParameters[kc.SIGNED_REQUEST];
    if (jwt.length % 4 > 0) {
      jwt = jwt.padRight(jwt.length + (4 - jwt.length % 4), '=');
    }
    var claims = jsonDecode(utf8.decode(base64.decode(jwt.split('.')[1])));
    await BlacklistCollection.add({
      kc.ISS: FACEBOOK,
      kc.SUB: claims[kc.USER_ID],
      kc.IAT: claims[kc.ISSUED_AT],
    });
    request.response.statusCode = HttpStatus.ok;
  }
}

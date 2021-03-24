import 'dart:io';
import 'dart:convert';

import 'package:http/http.dart';

import '../utilities/file_system.dart';

import './social_auth.dart';

import '../constants/keys.dart' as kc;
import '../constants/values.dart' as vc;
import '../constants/issuers.dart';

/// Class [GithubAuth] provides the overrides that are specific to the
/// Github authentication process.  Github does not provide OpenID Connect
/// ID Tokens, so an ID Token is created by the app.  ID Tokens and not
/// access_tokens are used for API authentication.  Github access_tokens
/// have no expiration.  The ID tokens created by the app will have a one
/// day expiration to ensure we check that the user hasn't removed the
/// authorization.
class GithubAuth extends SocialAuth {
  @override
  String get issuer => GITHUB;

  /// Github has two different endpoints to get user name data and to get
  /// email data
  @override
  Future<Map<String, dynamic>> addUserData(
      Map<String, dynamic> tokenData) async {
    tokenData = await _addUser(tokenData);
    tokenData = await _addEmail(tokenData);
    return tokenData;
  }

  /// Gets Github user data from the profile endpoint and adds it to the
  /// tokenData
  Future<Map<String, dynamic>> _addUser(Map<String, dynamic> tokenData) async {
    var response = await Client().get(
      Uri.parse(FileSystem.issuerData[issuer][kc.PROFILE_ENDPOINT]),
      headers: {
        HttpHeaders.acceptHeader: vc.APPLICATION_JSON,
        HttpHeaders.authorizationHeader: vc.BEARER + tokenData[kc.ACCESS_TOKEN],
      },
    );
    var userData = jsonDecode(response.body);
    tokenData.addAll({kc.NAME: userData[kc.NAME], kc.SUB: userData[kc.SUB_ID]});
    var nameParts = userData[kc.NAME].split(' ');
    if (nameParts.length > 1) tokenData[kc.LAST_NAME] = nameParts.last;
    if (nameParts.length > 0) tokenData[kc.FIRST_NAME] = nameParts.first;
    return tokenData;
  }

  /// Gets the email information.  Github provides a list of email addresses,
  /// and the goal is to get the primary email address if it's available.  This
  /// will depend on how the user has their Github account privacy setup.
  Future<Map<String, dynamic>> _addEmail(Map<String, dynamic> tokenData) async {
    var response = await Client().get(
      Uri.parse(FileSystem.issuerData[issuer][kc.EMAIL_ENDPOINT]),
      headers: {
        HttpHeaders.acceptHeader: 'application/json',
        HttpHeaders.authorizationHeader: 'Bearer ${tokenData[kc.ACCESS_TOKEN]}',
      },
    );
    var emailData = jsonDecode(response.body);
    // Github returns emails as a List of Maps, look for primary
    var email;
    for (var emailEntry in emailData) {
      if (emailEntry[kc.PRIMARY]) email = emailEntry[kc.EMAIL];
    }
    email ??= emailData[0][kc.EMAIL];
    tokenData[kc.EMAIL] = email;
    return tokenData;
  }

  /// Since Github access_tokens don't expire, we just do a token check to
  /// ensure that the access token is still valid.  If the user has removed
  /// the app their account, then this will get an unauthorized response which
  /// will be sent back to the client
  @override
  Future<Response> getRefreshToken() async {
    final refreshToken = req.headers[kc.REFRESH_TOKEN].first;
    final refreshEndpoint = FileSystem.issuerData[issuer][kc.REFRESH_ENDPOINT];

    return await Client().get(
      Uri.parse(refreshEndpoint),
      headers: {HttpHeaders.authorizationHeader: vc.BEARER + refreshToken},
    );
  }

  /// For github, there are no refresh tokens.  For consistency with all
  /// providers, the access token is stored as the refresh token.
  @override
  Map<String, dynamic> addRefreshTokenData(Map<String, dynamic> tokenData) {
    final accessToken = req.headers[kc.ACCESS_TOKEN].first;

    tokenData.addAll({
      kc.ISSUER: issuer,
      kc.REFRESH_TOKEN: refreshToken,
      kc.ACCESS_TOKEN: accessToken
    });
    return tokenData;
  }
}

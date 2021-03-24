import 'dart:io';
import 'dart:convert';

import 'package:http/http.dart';
import 'package:jose/jose.dart';

import '../utilities/file_system.dart';
import '../utilities/extensions.dart';
import '../database/blacklist_collection.dart';

import './social_auth.dart';

import '../constants/keys.dart' as kc;
import '../constants/values.dart' as vc;
import '../constants/issuers.dart';

/// Class [AppleAuth] provides the overrides that are specific to the
/// Apple authentication process.  Apple also provides an OpenID Connect
/// ID Token which is the primary token used for API authentication.
class AppleAuth extends SocialAuth {
  Uri _uri;

  @override
  String get issuer => APPLE;

  /// Apple provides the URI in the POST body and this URI can only be
  /// read once
  @override
  Future<Uri> get uri async =>
      _uri ??= Uri(query: await utf8.decoder.bind(req).join());

  /// Apple requires the client_secret to be generated manually from the
  /// private key that is downloaded during application registration on the
  /// Apple developer web site
  @override
  String get clientSecret {
    final keyId = FileSystem.issuerData[issuer][kc.KEY_ID];
    final pemKey = File(FileSystem.applePrivateKeyFile).readAsStringSync();
    final jwk = JsonWebKey.fromPem(pemKey, keyId: keyId);

    final claims = {
      kc.ISS: FileSystem.issuerData[issuer][kc.TEAM_ID],
      kc.IAT: DateTime.now().secondsSinceEpoch,
      kc.EXP: DateTime.now().secondsSinceEpoch + vc.FIVE_MINUTES,
      kc.AUD: FileSystem.issuerData[issuer][kc.AUDIENCE],
      kc.SUB: FileSystem.issuerData[issuer][kc.CLIENT_ID],
    };

    var secretBuilder = JsonWebSignatureBuilder()
      ..jsonContent = claims
      ..addRecipient(jwk, algorithm: vc.ALGORITHM);

    return secretBuilder.build().toCompactSerialization();
  }

  /// Apple has specific requirements on the headers provided when
  /// exchaning an authentication code for an access_token
  @override
  Map<String, String> get tokenHeaders => {
        HttpHeaders.acceptHeader: vc.APPLICATION_JSON,
        HttpHeaders.userAgentHeader: vc.CURL, // Apple needs this
      };

  /// Apple only provides user data during the first authentication.  A
  /// re-authentication of an already allowed app will not provided the
  /// user data, it must be saved in the database
  @override
  Future<Map<String, dynamic>> addUserData(
      Map<String, dynamic> tokenData) async {
    if (!(await uri).queryParameters.containsKey(kc.USER)) return tokenData;
    var user = jsonDecode((await uri).queryParameters[kc.USER]);
    tokenData.addAll({
      kc.NAME: '${user[kc.NAME][kc.FIRST_NAME]} ${user[kc.NAME][kc.LAST_NAME]}',
      kc.FIRST_NAME: user[kc.NAME][kc.FIRST_NAME],
      kc.LAST_NAME: user[kc.NAME][kc.LAST_NAME],
      kc.EMAIL: user[kc.EMAIL],
    });
    return tokenData;
  }

  /// Apple and Google require the refresh_token be requested with a POST
  /// request and with Apple requires this specific header
  @override
  Future<Response> getRefreshToken() async {
    return await Client().post(Uri.parse(refreshUrl),
        headers: {HttpHeaders.contentTypeHeader: vc.APPLICATION_URL_ENCODED});
  }

  /// Apple supports token revocation.  Apple sends the revoke information in
  /// a JWT.  The JWT signature is verfied with the Apple public keys.  Then,
  /// the apple user ID of the revoked token along with the issuer is
  /// stored in a blacklist that will reject any future attempts at using
  /// the ID token.
  static Future<void> revoke(HttpRequest request) async {
    final issuers = FileSystem.issuerData;
    var postBody = await utf8.decoder.bind(request).join();
    var payload = jsonDecode(postBody)[kc.PAYLOAD];
    var jwt = JsonWebToken.unverified(payload);
    var keyStore = JsonWebKeyStore()
      ..addKeySetUrl(Uri.parse(issuers[APPLE][kc.PUBLIC_KEY_ENDPOINT]));
    request.response.statusCode = HttpStatus.badRequest;
    if (await jwt.verify(keyStore)) {
      await BlacklistCollection.add({
        kc.ISS: APPLE,
        kc.SUB: jwt.claims.toJson()[kc.EVENTS][kc.SUB],
        kc.IAT: jwt.claims.toJson()[kc.IAT],
      });
      request.response.statusCode = HttpStatus.ok;
    }
  }
}

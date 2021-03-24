import 'dart:io';
import 'dart:async';

import 'package:jose/jose.dart';

import '../utilities/file_system.dart';
import '../utilities/extensions.dart';
import '../database/users_collection.dart';
import '../database/blacklist_collection.dart';

import '../constants/keys.dart' as kc;
import '../constants/errors.dart' as ec;
import '../constants/values.dart' as vc;
import '../constants/issuers.dart';

/// A group of static methods related to creation and validation of
/// jwt id_tokens
class IdToken {
  /// Validates an [idToken]. if it's a valid token, returns a map with
  /// 'email' key containing email address, otherwise, returns a map with
  /// 'error' key and a message.
  static Future<Map<String, String>> validate(String idToken) async {
    final issuers = FileSystem.issuerData;
    final jwt = JsonWebToken.unverified(idToken);

    // If token doesn't have an issuer or a known issuer, reject
    var containsIssuer = jwt.claims.toJson().containsKey(kc.ISS);
    if (!containsIssuer) return {kc.ERROR: ec.TOKEN_NO_ISSUER};
    var issuer = jwt.claims.toJson()[kc.ISS];
    if (issuer.contains(APPLE)) issuer = APPLE;
    if (issuer.contains(GOOGLE)) issuer = GOOGLE;
    if (!ISSUERS.contains(issuer)) return {kc.ERROR: ec.TOKEN_BAD_ISSUER};

    // If token is on blacklist, reject
    var sub = jwt.claims.toJson()[kc.SUB];
    var tokenExistsInBlacklist = BlacklistCollection.exists({
      kc.ISSUER: issuer,
      kc.SUB: sub,
    });
    if (await tokenExistsInBlacklist) return {kc.ERROR: ec.TOKEN_REVOKED};

    // If token doesn't have an email, reject
    var containsEmail = jwt.claims.toJson().containsKey(kc.EMAIL);
    if (!containsEmail) return {kc.ERROR: ec.NO_EMAIL_ADDRESS};
    final email = jwt.claims.toJson()[kc.EMAIL] as String;

    // if token is expired, reject
    final exp = DateTime(0).fromSecondsSinceEpoch(jwt.claims.toJson()[kc.EXP]);
    if (exp.isBefore(DateTime.now())) return {kc.ERROR: ec.TOKEN_EXPIRED};

    // If token had an email address that's not in the DB. Reject
    final user = await UsersCollection.getUser(email);
    if (user == null) return {kc.ERROR: ec.USER_NO_EXIST};

    // Github & facebook use our own internal public key for verification
    // Apple & Google have plublic keys for signature verification
    var keyStore = (issuers[issuer].containsKey(kc.PUBLIC_KEY_ENDPOINT))
        ? (JsonWebKeyStore()
          ..addKeySetUrl(
            Uri.parse(issuers[issuer][kc.PUBLIC_KEY_ENDPOINT]),
          ))
        : (JsonWebKeyStore()
          ..addKey(JsonWebKey.fromPem(
            File(FileSystem.publicKeyFile).readAsStringSync(),
          )));

    // The signature on the token is invalid
    if (!await jwt.verify(keyStore)) return {kc.ERROR: ec.TOKEN_KEY_BAD};

    // The token is valid
    return {kc.EMAIL: email};
  }

  static String generate(Map<String, dynamic> tokenData) {
    // If no expiration is given (Github), then force a check once a day
    var expiresAt = (tokenData.containsKey(kc.EXPIRES_IN))
        ? DateTime.now().secondsSinceEpoch + tokenData[kc.EXPIRES_IN]
        : DateTime.now().add(Duration(days: vc.ONE_DAY)).secondsSinceEpoch;

    // These are standard Json Web Token Claims as specified in section 10.1 of
    // https://tools.ietf.org/html/draft-ietf-oauth-json-web-token-25
    var claims = {
      kc.ISS: tokenData[kc.ISSUER],
      kc.SUB: tokenData[kc.SUB],
      kc.EMAIL: tokenData[kc.EMAIL],
      kc.NAME: tokenData[kc.NAME],
      kc.IAT: DateTime.now().secondsSinceEpoch,
      kc.EXP: expiresAt,
    };

    // The private key is used to sign the token
    var privateKey = File(FileSystem.privateKeyFile).readAsStringSync();
    var jwk = JsonWebKey.fromPem(privateKey);
    var idTokenBuilder = JsonWebSignatureBuilder()
      ..jsonContent = claims
      ..setProtectedHeader(kc.TYP, vc.JWT)
      ..setProtectedHeader(kc.ALG, vc.ALGORITHM)
      ..addRecipient(jwk, algorithm: vc.ALGORITHM);

    return idTokenBuilder.build().toCompactSerialization();
  }
}

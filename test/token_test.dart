import 'package:test/test.dart';
import 'package:jose/jose.dart';
import 'package:oauth_server_demo/auth/id_token.dart';
import 'package:oauth_server_demo/database/users_collection.dart';

import 'package:oauth_server_demo/constants/keys.dart' as kc;

const String idTokenNoIssuer =
    'eyJ0eXAiOiJqd3QiLCJhbGciOiJFUzI1NiJ9.eyJlbWFpbCI6Im1hcnRpbkBtbWZpbmsuY29tIiwibmFtZSI6Ik1hcnRpbiBGaW5rIiwiZXhwIjoxNjE2MjgzMDQxfQ.kbMmYG4h_sPq7pI8LhUKX52g-A_qvdizMmMe7Wxmv0WoqgkkwrF98-jLv0RVtEGQt4BeyVYNaKDzvBE98TnUjw';
const String idTokenBadIssuer =
    'eyJ0eXAiOiJqd3QiLCJhbGciOiJFUzI1NiJ9.eyJpc3MiOiJpbnZhbGlkIiwiZW1haWwiOiJtYXJ0aW5AbW1maW5rLmNvbSIsIm5hbWUiOiJNYXJ0aW4gRmluayIsImV4cCI6MTYxNjI4MzE4MH0.hZlztRJp0PF4BwX5SGtjyu0OQgnJs6ZeUxwU8YIu8wrj-sk2LAo9NrA4AO93dZBw4Zl0GkptqnOXtGZIUKqfDw';
const String idTokenNoEmail =
    'eyJ0eXAiOiJqd3QiLCJhbGciOiJFUzI1NiJ9.eyJpc3MiOiJnaXRodWIiLCJuYW1lIjoiTWFydGluIEZpbmsiLCJleHAiOjE2MTYyODMyNDJ9.1f37fKhv5QjZ1fPPSM8vn7Q4Oll2CwyPztWxcj5R1n98xd6xphGW4iFBnez-WUpZdcQuAJB98LW_PJpiM0rlhw';
const String idTokenExpired =
    'eyJ0eXAiOiJqd3QiLCJhbGciOiJFUzI1NiJ9.eyJpc3MiOiJnaXRodWIiLCJlbWFpbCI6InRlc3RAdGVzdC5jb20iLCJuYW1lIjoiTWFydGluIEZpbmsiLCJleHAiOjE2MTYyODMzMjR9.2HozTSqdBRCfMeFJyzF5PwpTXfLntmJ8MxnT7yDnivo2eyEP-4TlweWqm5prTYAzYGRczlPBRm8hR-mOaxVMZg';

void main() {
  var tokenData = Map<String, dynamic>.from({
    'firstName': 'Test',
    'lastName': 'User',
    'name': 'Test User',
    'email': 'test.user@test.com',
    'access_token': 'Fake access token', // Create user needs this
    'issuer': 'github',
  });

  group('Token:', () {
    test('Ensure valid token gets accepted', () async {
      var token = IdToken.generate(tokenData);
      await UsersCollection.createUser(tokenData);
      expect((await IdToken.validate(token))['email'], tokenData['email']);
      await UsersCollection.delete(email: tokenData['email']);
    });
    test('Ensure token with no issuer is rejected', () async {
      expect(
        (await IdToken.validate(idTokenNoIssuer)).containsKey(kc.ERROR),
        true,
      );
    });
    test('Ensure token with invalid issuer is rejected', () async {
      expect(
        (await IdToken.validate(idTokenBadIssuer)).containsKey(kc.ERROR),
        true,
      );
    });
    test('Ensure token with no email is rejected', () async {
      expect(
        (await IdToken.validate(idTokenNoEmail)).containsKey(kc.ERROR),
        true,
      );
    });
    test('Ensure expired token is rejected', () async {
      expect(
        (await IdToken.validate(idTokenExpired)).containsKey(kc.ERROR),
        true,
      );
    });
    test('Ensure token with user not in DB is rejected', () async {
      var idTokenUserNotExist = IdToken.generate(tokenData);
      expect(
        (await IdToken.validate(idTokenUserNotExist)).containsKey(kc.ERROR),
        true,
      );
    });
    test('Ensure token with invalid signature is rejected', () async {
      await UsersCollection.createUser(tokenData);
      var badKeyIdToken = _generateBadKeyIdToken(tokenData);
      var validated = await IdToken.validate(badKeyIdToken);
      await UsersCollection.delete(email: tokenData['email']);
      expect(validated.containsKey(kc.ERROR), true);
    });
  });
}

String _generateBadKeyIdToken(Map<String, dynamic> tokenData) {
  var badPrivateKey = '''-----BEGIN EC PRIVATE KEY-----
MHcCAQEEIByWEP8mbgcKhBukvatrGN/G9f6S3zcFAv08fOa1qYZDoAoGCCqGSM49
AwEHoUQDQgAEAxl3VauaVHIDBG1aINurEKF+cbqojuf7sOza7e4IgMOSUsgoD5E9
MhSidpwa1HP09KJuyhe5p2n6OFiDdhB5gQ==
-----END EC PRIVATE KEY-----''';

  var jwk = JsonWebKey.fromPem(badPrivateKey);
  var idTokenBuilder = JsonWebSignatureBuilder()
    ..jsonContent = tokenData
    ..setProtectedHeader('typ', 'jwt')
    ..setProtectedHeader('alg', 'ES256')
    ..addRecipient(jwk, algorithm: 'ES256');

  return idTokenBuilder.build().toCompactSerialization();
}

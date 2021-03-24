import 'dart:io';
import 'package:test/test.dart';

import 'package:oauth_server_demo/constants/issuers.dart';
import 'package:oauth_server_demo/utilities/file_system.dart';

void main() {
  group('FileSystem: ', () {
    test('Project folder exists', () {
      expect(Directory(FileSystem.projectFolder).exists(), completion(true));
    });
    test('HTML folder exists', () {
      expect(Directory(FileSystem.authHtmlFolder).exists(), completion(true));
    });
    test('Issuers file exists', () {
      expect(File(FileSystem.issuersFile).exists(), completion(true));
    });
    test('Private key file exists', () {
      expect(File(FileSystem.privateKeyFile).exists(), completion(true));
    });
    test('Public key file exists', () {
      expect(File(FileSystem.publicKeyFile).exists(), completion(true));
    });
    test('Apple private file exists', () {
      expect(File(FileSystem.applePrivateKeyFile).exists(), completion(true));
    });
    test('Logo files exist', () {
      ISSUERS.forEach((issuer) {
        var logoFile =
            File(FileSystem.authHtmlFolder + '/images/${issuer}_logo.png');
        expect(logoFile.exists(), completion(true));
      });
      var logoFile =
          File(FileSystem.authHtmlFolder + '/images/oauth2_logo.png');
      expect(logoFile.exists(), completion(true));
    });
    test('CSS file exists', () {
      var cssFile = File(FileSystem.authHtmlFolder + '/styles/styles.css');
      expect(cssFile.exists(), completion(true));
    });
    test('Required HTML files exist', () {
      ISSUERS.forEach((issuer) {
        var successFile =
            File(FileSystem.authHtmlFolder + '/${issuer}_auth_success.html');
        var failedFile =
            File(FileSystem.authHtmlFolder + '/${issuer}_auth_failed.html');
        expect(successFile.exists(), completion(true));
        expect(failedFile.exists(), completion(true));
      });
      var failedFile =
          File(FileSystem.authHtmlFolder + '/noissuer_auth_failed.html');
      var indexFile = File(FileSystem.authHtmlFolder + '/index.html');
      var notFoundFile = File(FileSystem.authHtmlFolder + '/not_found.html');
      var favIcoFile = File(FileSystem.authHtmlFolder + '/favicon.ico');
      expect(failedFile.exists(), completion(true));
      expect(indexFile.exists(), completion(true));
      expect(notFoundFile.exists(), completion(true));
      expect(favIcoFile.exists(), completion(true));
    });
  });
}

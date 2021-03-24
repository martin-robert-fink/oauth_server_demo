import 'dart:io';
import 'dart:convert';

import 'package:http/http.dart';

import '../utilities/file_system.dart';

import './social_auth.dart';

import '../constants/keys.dart' as kc;
import '../constants/values.dart' as vc;
import '../constants/issuers.dart';

/// Class [GoogleAuth] provides the overrides that are specific to the
/// Google authentication process.  Google also provides an OpenID Connect
/// ID Token which is the primary token used for API authentication.
class GoogleAuth extends SocialAuth {
  @override
  String get issuer => GOOGLE;

  /// Google provides a profile endpoint that can be used at will to retrieve
  /// user data (email, name)
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
      kc.LAST_NAME: userData[kc.LAST_NAME],
      kc.FIRST_NAME: userData[kc.FIRST_NAME],
      kc.EMAIL: userData[kc.EMAIL],
    });
    return tokenData;
  }
}

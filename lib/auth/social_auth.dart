import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:http/http.dart';

import '../server/message_broker.dart';
import '../utilities/file_system.dart';
import '../database/users_collection.dart';
import '../auth/id_token.dart';

import '../constants/keys.dart' as kc;
import '../constants/server.dart' as sc;
import '../constants/values.dart' as vc;
import '../constants/devices.dart' as dc;
import '../constants/errors.dart' as ec;

/// [SocialAuth] is the base class for all signing by <issuer> providers.  It
/// provides all the base functionality which is common to all/most issuers
abstract class SocialAuth {
  /// The [req] property is provided by the [authenticate] method and is used
  /// by all other methods so it doesn't have to be passed around as a
  /// parameter and it's possible to setup many methods as getters since no
  /// other parameters are needed.  It needs to be public to be available to
  /// derived classes
  HttpRequest req;

  /// Each implementation of a concrete class must provide the [issuer]
  String get issuer;

  /// There is no default implementation of [addUserData] since each issuer
  /// is different in how that information is obtained
  Future<Map<String, dynamic>> addUserData(Map<String, dynamic> tokenData);

  /// Apple overrides [uri] since it comes in via the POST body
  Future<Uri> get uri async => req.uri;

  /// Apple has specific requirements for headers and will override this
  Map<String, String> get tokenHeaders =>
      {HttpHeaders.acceptHeader: vc.APPLICATION_JSON};

  /// Apple has requires client_secret to be generated from a private key
  /// and overrides this getter
  String get clientSecret => FileSystem.issuerData[issuer][kc.CLIENT_SECRET];

  /// The [state] is used to prevent CSRF (Cross-Site Request Forgery).  The
  /// client generates a [state] using a UUID.  The client generates this value
  /// and it will be checked to ensure that it matches what the client sent
  Future<String> get state async => (await uri).queryParameters[kc.STATE];

  /// [authenticate] is the entry point that is called when the issuers calls
  /// the redirect URL which must be setup in the confguration of each issuer
  /// the redirect URL should be formated as:
  /// https://auth.domain.com/auth/[issuer]
  /// This is also the entry point to request a refresh_token.  The client
  /// calls this entry point using:
  /// https://auth.domain.com/refresh/[issuer]
  /// This method does not return anything.  The tokenData is sent back via
  /// the client redirect; or the refresh token is sent back in the response
  Future<void> authenticate(HttpRequest request) async {
    req = request;
    var tokenData = await _getToken();
    if (!tokenData.containsKey(kc.ERROR)) {
      tokenData = (await UsersCollection.createUser(tokenData))
          ? tokenData
          : {kc.ERROR: ec.CREATE_USER_FAILED};
    }
    // This will either send back the tokenData which will either have
    // token information, or error information.
    MessageBroker.broadcast(jsonEncode(tokenData));
    await _redirectClient(tokenData);
  }

  // Make sure the request sent by the [issuer] has an authentication code
  // and a CSRF state that matches what the client sent
  Future<Map<String, dynamic>> _checkRequest() async {
    var queryParameters = (await uri).queryParameters;
    if (!queryParameters.containsKey(kc.CODE)) return {kc.ERROR: ec.NO_CODE};
    if (!queryParameters.containsKey(kc.STATE)) return {kc.ERROR: ec.NO_STATE};
    var isStateValid = await _isStateValid(await state);
    if (!isStateValid) return {kc.ERROR: ec.BAD_STATE};
    return {};
  }

  // Sends the http POST request to the correct issuer to get the initial
  // token information.  The user data and for issuers that don't provide
  // an OpenID id_token, one is generated and added as well.
  Future<Map<String, dynamic>> _getToken() async {
    var checkRequest = await _checkRequest();
    if (checkRequest.containsKey(kc.ERROR)) return checkRequest;

    var tokenUri = Uri.parse(await _tokenUrl);
    var response = await Client().post(tokenUri, headers: tokenHeaders);

    Map<String, dynamic> tokenData = jsonDecode(response.body);
    tokenData.addAll({kc.STATE: await state, kc.ISSUER: issuer});
    // if there's no access token, then an error occured, stop
    if (!tokenData.containsKey(kc.ACCESS_TOKEN)) return tokenData;
    tokenData = await addUserData(tokenData);
    tokenData = await _addIdToken(tokenData);
    return tokenData;
  }

  // Builds the URL with all the paramters as required by each issuer
  Future<String> get _tokenUrl async {
    final code = (await uri).queryParameters[kc.CODE];
    final redirectUri = '${sc.REDIRECT_BASE}$issuer';
    final tokenEndpoint = FileSystem.issuerData[issuer][kc.TOKEN_ENDPOINT];
    final clientId = FileSystem.issuerData[issuer][kc.CLIENT_ID];
    return '$tokenEndpoint'
        '?${kc.CLIENT_ID}=$clientId'
        '&${kc.CLIENT_SECRET}=$clientSecret'
        '&${kc.CODE}=$code'
        '&${kc.REDIRECT_URI}=$redirectUri'
        '&${kc.STATE}=$state'
        '&${kc.GRANT_TYPE}=${kc.AUTHORIZATION_CODE}';
  }

  // After all the tokenData is assembled it is sent back to the client
  // For mobile and MacOS, the redirect is custom URL scheme which brings
  // the app to the foreground.  For Linux/Windows, the redirect is a web
  // browser confirmation window that the authentication succeeded or failed.
  Future<void> _redirectClient(Map<String, dynamic> tokenData) async {
    req.response.headers.contentType = ContentType.html;
    final userAgent =
        req.headers[HttpHeaders.userAgentHeader].first.toLowerCase();
    var redirectURL = sc.CUSTOM_SCHEME;
    if (!userAgent.toLowerCase().contains(dc.IPHONE) &&
        !userAgent.toLowerCase().contains(dc.ANDROID) &&
        !userAgent.toLowerCase().contains(dc.MACINTOSH)) {
      redirectURL = (tokenData == null)
          ? sc.WWW_HOST + '${issuer}_auth_failed.html'
          : sc.WWW_HOST + '${issuer}_auth_success.html';
    }
    await req.response.redirect(Uri.parse(redirectURL));
  }

  /// This is called by the client through the refresh API call
  /// It gets the refreshToken from the issuer, the constructs the
  /// remaining parts (eg idToken if needed) and sends back the
  /// refreshed token to the client.
  Future<void> refreshToken() async {
    var response = await getRefreshToken();
    req.response.statusCode = response.statusCode;
    if (response.statusCode != HttpStatus.ok) return;
    req.response.headers.contentType = ContentType.json;
    Map<String, dynamic> tokenData = jsonDecode(response.body);
    tokenData = addRefreshTokenData(tokenData);
    tokenData = await _addIdToken(tokenData);
    req.response.write(jsonEncode(tokenData));
  }

  /// Some providers use a POST call which will use this method
  /// others need a GET call and will override this method
  Future<Response> getRefreshToken() async {
    return await Client().post(Uri.parse(refreshUrl));
  }

  /// Builds the correct URL to get the refresh token. Some issuers need
  /// to provide a unique URl construction and will override this
  String get refreshUrl {
    final refreshToken = req.headers[kc.REFRESH_TOKEN].first;
    final refreshEndpoint = FileSystem.issuerData[issuer][kc.REFRESH_ENDPOINT];
    final clientId = FileSystem.issuerData[issuer][kc.CLIENT_ID];
    return '$refreshEndpoint'
        '?${kc.CLIENT_ID}=$clientId'
        '&${kc.CLIENT_SECRET}=$clientSecret'
        '&${kc.REFRESH_TOKEN}=$refreshToken'
        '&${kc.GRANT_TYPE}=${kc.REFRESH_TOKEN}';
  }

  /// This adds some missing data needed by the client, or needs to be
  /// properly constructed by the client.  Some issuers override this
  /// method for properly constructed tokenData
  Map<String, dynamic> addRefreshTokenData(Map<String, dynamic> tokenData) {
    tokenData.addAll({kc.ISSUER: issuer, kc.REFRESH_TOKEN: refreshToken});
    return tokenData;
  }

  /// Adds an idToken to the tokenData for issuers that don't provide
  /// the idToken
  Future<Map<String, dynamic>> _addIdToken(
    Map<String, dynamic> tokenData,
  ) async {
    // only add an id_token if one doesn't already exist
    if (tokenData.containsKey(kc.ID_TOKEN)) return tokenData;

    tokenData.addAll({kc.ID_TOKEN: IdToken.generate(tokenData)});
    return tokenData;
  }

  // This creates a Future which will complete when either an isolate returns
  // a valid check on state; or all isolates have been checked and there is
  // no valid state.  A message is broadcast to all isolates to check for a
  // valid state.  The isolates also get a sendPort to send a message back
  // indicating if a state was found (non-null) or not (null)
  Future<dynamic> _isStateValid(String state) {
    final receivePort = ReceivePort();
    final completer = Completer();
    var messagesReceived = 0;
    var timeout;

    // If one isolate returns with a valid state; or all isolates return
    // without a valid state, complete the Future.
    void complete(bool isValid) {
      timeout.cancel();
      receivePort.close();
      completer.complete(isValid);
    }

    // Just in case, timeout if we don't get all the isolate replies
    // Could happen if an isolate is hung or dead
    timeout = Timer(Duration(seconds: 10), () => complete(false));

    // Wait for isolates to send back a valid state and stop as soon as we
    // get one
    receivePort.listen((message) {
      if (message != null) complete(true);
      if (++messagesReceived == MessageBroker.numSendPorts) complete(false);
    });

    // Broadcast to all isolates the state we're looking for and a way to
    // send a message back to this listener
    MessageBroker.broadcast({state: receivePort.sendPort});
    return completer.future;
  }

  /// static method [clientId] is a utility function to return the
  /// client_id to the client.  It keeps the client_id on the server.
  static void clientId(HttpRequest request) {
    try {
      final issuer = request.headers[kc.ISSUER].first.toLowerCase();
      final clientId = FileSystem.issuerData[issuer][kc.CLIENT_ID];
      if (clientId == null) throw Exception();
      request.response.headers.set(kc.CLIENT_ID, clientId);
      request.response.statusCode = HttpStatus.ok;
    } catch (_) {
      request.response.statusCode = HttpStatus.badRequest;
    }
  }
}

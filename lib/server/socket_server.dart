import 'dart:io';
import 'dart:convert';

import 'package:meta/meta.dart';

import 'api_server.dart';

import '../constants/keys.dart' as kc;

/// The client will start the auth process by establishing a webSocket
/// connection and passing a [state] to prevent CSRF attacks.  When the
/// issuer redirects to the server with an authentication code, it will
/// contain the [state] and it can be compared to what the client sent.
class SocketServer {
  WebSocket _webSocket;
  String _state;

  /// The [state] used to request an authentication code from an issuer.
  /// The [state] is used to match the received authentication code
  String get state => _state;

  // Transforms the request into a websocket and starts listening for
  // a [state].
  Future<void> start(HttpRequest request) async {
    _webSocket =
        await WebSocketTransformer.upgrade(request).catchError(_onError);
    _webSocket.listen(
      _listener,
      onError: (error) => _onError(error),
      cancelOnError: false,
    );
    // Wait for the socket to close.
    try {
      await _webSocket.done;
    } catch (error) {
      _onError(error);
    }
  }

  /// Used to send the access token and id token data back to the client that
  /// initiated the authentication request.
  Future<void> send({@required Map<String, dynamic> tokenData}) async {
    if (_webSocket.readyState == WebSocket.open) {
      _webSocket.add(jsonEncode(tokenData));
    }
    await _closeSocket();
  }

  // The only [data] expected from the client is the [state] used to
  // match the authentication code back to the client.
  void _listener(data) {
    final clientData = Map<String, String>.from(jsonDecode(data));
    _state = clientData[kc.STATE];
  }

  // Close the WebSocket connection.  This is called after sending the access
  // token data back to the client.
  Future<void> _closeSocket() async {
    if (_webSocket.readyState == WebSocket.open) {
      await _webSocket.close(WebSocketStatus.normalClosure);
    }
    ApiServer.socketServers.remove(this);
  }

  // Log any errors
  void _onError(error) {
    print('SocketServer: $error');
  }
}

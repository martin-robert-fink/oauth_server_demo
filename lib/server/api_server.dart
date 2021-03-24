import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import '../database/blacklist_collection.dart';
import '../router/host_router.dart';

import 'message_broker.dart';
import 'socket_server.dart';

import '../constants/server.dart' as sc;
import '../constants/keys.dart' as kc;
import '../constants/values.dart' as vc;

/// Creates an ApiServer that listens for HTTPS and WSS requests on the
/// SSL port.  Each request received is routed through [HostRouter] for
/// processing.  Technically, this processes both API and AUTH requests.
class ApiServer {
  ApiServer(this._mainIsolateSendPort) {
    _mainIsolateSendPort.send(_receivePort.sendPort);
    _receivePort.listen(_apiServerMessageHandler);
  }

  static final List<SocketServer> socketServers = [];
  final _hostRouter = HostRouter();
  final SendPort _mainIsolateSendPort;
  final _receivePort = ReceivePort();

  Future<void> startApiServer() async {
    final securityContext = SecurityContext()
      ..useCertificateChain(sc.SSL_FULL_CHAIN_PATH)
      ..setClientAuthorities(sc.CA_PATH)
      ..usePrivateKey(sc.SSL_KEY_PATH);

    final apiServer = await HttpServer.bindSecure(
      InternetAddress.anyIPv4,
      sc.SSL_PORT,
      securityContext,
      requestClientCertificate: true,
      shared: true,
    ).catchError((error, stacktrace) {
      print('HttpServer exception: $error; $stacktrace');
      exit(1);
    });
    // Adds a couple of default headers from the Dart default for increased
    // security
    apiServer.defaultResponseHeaders
        .add(kc.STRICT_TRANSPORT_SECURITY, vc.MAX_AGE);
    apiServer.defaultResponseHeaders
        .add(kc.CONTENT_SECURITY_POLICY, vc.DEFAULT_SRC);

    print('${Isolate.current.debugName} running...');

    // Once a day, go cleanup any old blacklisted tokens
    var oncePerDay = const Duration(days: vc.ONE_DAY);
    Timer.periodic(oncePerDay, (_) => BlacklistCollection.cleanUp());

    // Start the router
    await _hostRouter.route(apiServer).catchError((error, stackTrace) {
      print('Host router error: $error; Stacktrace: $stackTrace');
      apiServer.close(force: true);
      startApiServer(); // Restart the API server
    });
  }

  // Receives the list of all the sendPorts that can then be used for
  // broadcasting messages to all isolates
  //
  // A String is the tokenData to send back to the client that made the
  // initial request

  // If a Map message is directed to a SocketServer owned by this API Server
  // then tell the socketServer to send the token data back to the client
  void _apiServerMessageHandler(dynamic message) {
    if (message is List<SendPort>) {
      MessageBroker.sendPorts = message;
    } else if (message is String) {
      var tokenData = jsonDecode(message);
      _findSocketServerWith(tokenData[kc.STATE])?.send(tokenData: tokenData);
    } else if (message is Map<String, SendPort>) {
      var state = message.keys.first;
      var sendPort = message.values.first;
      sendPort.send((_findSocketServerWith(state) == null) ? false : true);
    }
  }

  SocketServer _findSocketServerWith(String state) {
    for (var socketServer in ApiServer.socketServers) {
      if (socketServer.state == state) return socketServer;
    }
    return null;
  }
}

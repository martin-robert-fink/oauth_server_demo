import 'dart:io';
import 'dart:async';
import 'dart:convert';

import 'package:oauth_server_demo/server/api_server.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';
import 'package:pedantic/pedantic.dart';

import 'package:oauth_server_demo/router/host_router.dart';

const WS_HOST = 'ws://localhost';
const PORT = 3000;

Future<void> main() async {
  String state;
  String issuer;
  HttpServer httpServer;
  final hostRouter = HostRouter();

  setUp(() async {
    state = Uuid().v4();
    issuer = 'google';
    var httpServer = await HttpServer.bind(
      InternetAddress.anyIPv4,
      PORT,
      shared: true,
    );
    unawaited(hostRouter.route(httpServer));
  });

  tearDown(() {
    httpServer?.close();
  });

  group('SocketServer:', () {
    test('Sends/receives data to/from client', () async {
      final ws = await WebSocket.connect('$WS_HOST:$PORT/v1/wss',
          headers: {'host': 'api.YOURDOMAIN.com'});
      if (ws.readyState != WebSocket.open) throw Exception();
      ws.add(json.encode({'state': state, 'issuer': issuer}));
      await Future.delayed(Duration(milliseconds: 50));
      expect(ApiServer.socketServers.first.state, state);
      ws.listen((data) {
        final tokenData = Map<String, String>.from(jsonDecode(data));
        expect(tokenData.containsKey('access_token'), true);
      });
      await ApiServer.socketServers.first.send(
        tokenData: {'access_token': 'Token Data'},
      );
    });
  });
}

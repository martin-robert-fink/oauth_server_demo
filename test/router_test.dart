import 'dart:io';
import 'package:http/http.dart';
import 'package:test/test.dart';
import 'package:pedantic/pedantic.dart';

import 'package:oauth_server_demo/router/host_router.dart';

// A LOCAL_HOST_TEST will create a single http host within the test
// and use that.  If false, then the main server needs to be running
// to the tests can run against that.
const LOCAL_HOST_TEST = true;
const HEADERS_HOST = 'auth.YOURDOMAIN.com';

Future<void> main() async {
  HttpServer httpServer;
  final hostRouter = HostRouter();
  var HOST = 'http://localhost';
  var PORT = 3000;

  if (!LOCAL_HOST_TEST) {
    HOST = 'https://auth.YOURDOMAIN.com';
    PORT = 443;
  }

  setUp(() async {
    if (LOCAL_HOST_TEST) {
      httpServer = await HttpServer.bind(InternetAddress.loopbackIPv4, PORT);
      unawaited(hostRouter.route(httpServer));
    }
  });

  tearDown(() {
    httpServer?.close();
  });

  group('Router:', () {
    test('Bad host gets notAcceptable', () async {
      var response = await Client()
          .head(Uri.parse('$HOST:$PORT/'), headers: {'host': 'bad.host.com'});
      expect(response.statusCode, HttpStatus.notAcceptable);
    });

    test('Unsupported methods send back error', () async {
      var response = await Client()
          .head(Uri.parse('$HOST:$PORT/'), headers: {'host': HEADERS_HOST});
      expect(response.statusCode, HttpStatus.methodNotAllowed);
    });

    test('Unsupported GET requests send back error', () async {
      var response = await Client()
          .get(Uri.parse('$HOST:$PORT/'), headers: {'host': HEADERS_HOST});
      expect(response.statusCode, HttpStatus.badRequest);
    });

    test('Unsupported POST requests send back error', () async {
      var response = await Client()
          .post(Uri.parse('$HOST:$PORT/'), headers: {'host': HEADERS_HOST});
      expect(response.statusCode, HttpStatus.badRequest);
    });

    test('Valid GET requests returns ok', () async {
      var response = await Client().get(Uri.parse('$HOST:$PORT/v1/test'),
          headers: {'host': HEADERS_HOST});
      expect(response.statusCode, HttpStatus.ok);
    });

    test('Valid POST requests returns ok', () async {
      var response = await Client().post(Uri.parse('$HOST:$PORT/v1/test'),
          headers: {'host': HEADERS_HOST});
      expect(response.statusCode, HttpStatus.ok);
    });

    test('v1/clientid GET requests with valid headers returns ok', () async {
      var response = await Client().get(
        Uri.parse('$HOST:$PORT/v1/clientid'),
        headers: {'issuer': 'github', 'host': HEADERS_HOST},
      );
      expect(response.statusCode, HttpStatus.ok);
    });

    test('v1/clientid GET requests with bad headers returns badRequest',
        () async {
      var response = await Client().get(
        Uri.parse('$HOST:$PORT/v1/clientid'),
        headers: {'issuerX': 'github', 'host': HEADERS_HOST},
      );
      expect(response.statusCode, HttpStatus.badRequest);
      response = await Client().get(
        Uri.parse('$HOST:$PORT/v1/clientid'),
        headers: {'issuer': 'githubx', 'host': HEADERS_HOST},
      );
      expect(response.statusCode, HttpStatus.badRequest);
    });
  });
}

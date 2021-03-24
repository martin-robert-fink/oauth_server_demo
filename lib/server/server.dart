import 'dart:io';
import 'dart:isolate';

import 'api_server.dart';

/// This is the main entry point to start the server and all the
/// isolates that will respond to API/Auth requests
class Server {
  final maxIsolates = Platform.numberOfProcessors;
  static final List<ApiServer> apiServers = [];
  static final List<Isolate> isolates = [];
  static final List<SendPort> sendPorts = [];

  /// Starts all the isolates (API Servers) on the server and waits for a
  /// Ctrl-C signal to terminal the app.
  Future<void> start() async {
    // Ports for message handling with the isolates
    final rootReceivePort = ReceivePort();
    final exitReceivePort = ReceivePort();
    final errorReceivePort = ReceivePort();
    rootReceivePort.listen(_rootMessageHandler);
    exitReceivePort.listen((msg) => print('Terminated: ${msg ?? 'Normal'}'));
    errorReceivePort.listen((error) {
      print('Isolate error: ${error[0] ?? 'None'}');
      print('Stack Trace: ${error[1] ?? 'None'}');
    });

    // Setup Ctrl-C Listener to make it easy to terminate the app
    _listenForSigint();

    // Spawn the API servers (one per hardware thread).
    for (var i = 0; i < maxIsolates; i++) {
      isolates.add(await Isolate.spawn(
        _createApiServer,
        rootReceivePort.sendPort,
        onError: errorReceivePort.sendPort,
        onExit: exitReceivePort.sendPort,
        errorsAreFatal: false,
        debugName: 'API Server ${i + 1}',
      ).catchError((error) {
        print('Isolate spawn error: $error');
      }));
    }
  }

  static Future<void> _createApiServer(SendPort rootSendPort) async {
    apiServers.add(ApiServer(rootSendPort));
    await apiServers.last.startApiServer();
  }

// All the isolates send their sendPorts.  In order to be able to broadcast
// messages from one isolate to all other isolates, we need to collect the
// sendPorts and once we have them all (based on the number of hardware
// threads there are), we send the port list to all other isolates.
  Future<void> _rootMessageHandler(dynamic message) async {
    if (message is SendPort) {
      sendPorts.add(message);
      // Once all the SendPorts have been collected, send the port list
      // to all isolates.
      if (sendPorts.length == maxIsolates) {
        for (var sendPort in sendPorts) {
          sendPort.send(sendPorts);
        }
        await Future.delayed(Duration(milliseconds: 50));
        print('All Servers Ready - Press Ctrl-C to exit');
      }
    }
  }

// When a Ctrl-C signal is received, then gracefully kill all the isolates,
// including terminating this app.
  void _listenForSigint() {
    ProcessSignal.sigint.watch().listen((_) async {
      print('');
      for (var isolate in isolates) {
        print('Killing ${isolate?.debugName}...');
        isolate?.kill();
        isolate = null;
      }
      await Future.delayed(Duration(seconds: 2));
      print('All servers killed, exiting app.');
      exit(0); // Kills this app (the final isolate)
    });
  }
}

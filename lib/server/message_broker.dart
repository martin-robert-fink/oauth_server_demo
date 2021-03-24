import 'dart:isolate';

/// Class that contains all the static properties and methods to handle
/// broadcast of isolate messages
class MessageBroker {
  static int get numSendPorts => _sendPorts.length;

  static final _sendPorts = <SendPort>[];

  /// When all isolates (API Servers) are running, sets the list of all
  /// the sendPorts and save them so we can broadcast messages to everyone.
  /// The _isolateMessageHandler in the API Server is responsible for
  /// sending the list of sendPorts when they are ready
  static set sendPorts(List<SendPort> sendPorts) =>
      _sendPorts.addAll(sendPorts);

  /// Broadcast a [message] to all other apiServers currently running.
  /// [message] is limited to primitives as well as List/Map of primitives.
  static void broadcast(dynamic message) {
    for (var sendPort in _sendPorts) {
      sendPort.send(message);
    }
  }
}

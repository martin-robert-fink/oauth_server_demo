import 'dart:io';
import 'dart:isolate';
import 'package:test/test.dart';
import 'package:oauth_server_demo/server/message_broker.dart';

void main() {
  group('MessageBroker:', () {
    test('Broadbast messge to all sendports works', () async {
      var sendPorts = <SendPort>[];
      var receivePorts = <ReceivePort>[];
      var messagesReceived = 0;
      for (var i = 0; i < Platform.numberOfProcessors; i++) {
        receivePorts.add(ReceivePort());
        sendPorts.add(receivePorts.last.sendPort);
      }
      receivePorts.forEach((port) => port.listen((_) => messagesReceived++));
      MessageBroker.sendPorts = sendPorts;
      MessageBroker.broadcast('test message');
      await Future.delayed(Duration(milliseconds: 1));
      expect(MessageBroker.numSendPorts, messagesReceived);
    });
  });
}

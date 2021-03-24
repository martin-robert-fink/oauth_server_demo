import 'dart:io';
import 'dart:convert';

import 'validate.dart';

import '../server/socket_server.dart';
import '../server/api_server.dart';
import '../auth/id_token.dart';
import '../database/users_collection.dart';
import '../database/tasks_collection.dart';

import '../constants/keys.dart' as kc;
import '../constants/paths.dart' as pc;

/// Router for GET requests
class ApiGetRouter {
  /// Main router function for all GET requests and the POST request from
  /// Apple that is sent here from the POST router
  Future<void> route(HttpRequest request) async {
    request.response.statusCode = HttpStatus.badRequest;
    if (request.uri.pathSegments.length < 2) return;
    switch (request.uri.pathSegments[1]) {
      case pc.TEST:
        _v1Test(request);
        break;
      case pc.WSS:
        await _v1Wss(request);
        break;
      case pc.TASK:
        if (!await Validate.isRequestValid(request)) return;
        await _v1Task(request);
        break;
      default:
        request.response.statusCode = HttpStatus.badRequest;
        break;
    }
  }

  // Only used for testing the get router
  void _v1Test(HttpRequest request) {
    request.response.statusCode = HttpStatus.ok;
  }

  // Creates SocketServer object then starts it up
  Future<void> _v1Wss(HttpRequest request) async {
    ApiServer.socketServers.add(SocketServer());
    await ApiServer.socketServers.last.start(request);
  }

  Future<void> _v1Task(HttpRequest request) async {
    var authHeader = request.headers[HttpHeaders.authorizationHeader];
    var idToken = authHeader.first.split(' ').last;
    var email = (await IdToken.validate(idToken))[kc.EMAIL];
    var ownerId = (await UsersCollection.getUser(email))[kc.ID].toString();
    switch (request.uri.pathSegments.last) {
      case pc.GET_ALL:
        var todos = await TasksCollection.getAll(ownerId);
        request.response.headers.contentType = ContentType.json;
        request.response.statusCode = HttpStatus.ok;
        request.response.write(jsonEncode(todos));
        break;
      case pc.COUNT:
        var count = await TasksCollection.count(ownerId);
        request.response.statusCode = HttpStatus.ok;
        request.response.write(count);
        break;
    }
  }
}

import 'dart:convert';
import 'dart:io';

import 'validate.dart';
import '../auth/id_token.dart';
import '../database/users_collection.dart';
import '../database/tasks_collection.dart';

import '../constants/keys.dart' as kc;
import '../constants/paths.dart' as pc;

/// Router for DELETE requests
class ApiDeleteRouter {
  /// Main router function for all DELETE request from
  /// Apple that is sent here from the POST router
  Future<void> route(HttpRequest request) async {
    request.response.statusCode = HttpStatus.badRequest;
    if (request.uri.pathSegments.length < 2) return;
    switch (request.uri.pathSegments[1]) {
      case pc.TASK:
        if (!await Validate.isRequestValid(request)) return;
        await _v1DeleteTask(request);
        break;
      default:
        request.response.statusCode = HttpStatus.badRequest;
        break;
    }
  }

  Future<void> _v1DeleteTask(HttpRequest request) async {
    var authHeader = request.headers[HttpHeaders.authorizationHeader];
    var idToken = authHeader.first.split(' ').last;
    var email = (await IdToken.validate(idToken))[kc.EMAIL];
    var taskId = request.uri.queryParameters[kc.QID];
    var ownerId = (await UsersCollection.getUser(email))[kc.ID].toString();
    var result = await TasksCollection.delete(taskId, ownerId);
    request.response.statusCode = HttpStatus.ok;
    if (result[kc.ERR] != null) {
      request.response.headers.contentType = ContentType.json;
      request.response.statusCode = HttpStatus.notFound;
      request.response.write(jsonEncode(result[kc.ERR]));
    }
  }
}

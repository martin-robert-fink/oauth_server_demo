import 'dart:io';
import 'dart:convert';

import 'validate.dart';
import '../auth/id_token.dart';
import '../database/tasks_collection.dart';
import '../database/users_collection.dart';

import '../constants/keys.dart' as kc;
import '../constants/paths.dart' as pc;

/// Routes POST requests
class ApiPostRouter {
  Future<void> route(HttpRequest request) async {
    request.response.statusCode = HttpStatus.badRequest;
    if (request.uri.pathSegments.length < 2) return;
    switch (request.uri.pathSegments[1]) {
      case pc.TEST:
        request.response.statusCode = HttpStatus.ok;
        break;
      case pc.ADD:
        if (!await Validate.isRequestValid(request)) return;
        await _add(request);
        break;
      default:
        request.response.statusCode = HttpStatus.badRequest;
        break;
    }
  }

  Future<void> _add(HttpRequest request) async {
    var todo = jsonDecode(await utf8.decoder.bind(request).join());
    var authHeader = request.headers[HttpHeaders.authorizationHeader];
    var idToken = authHeader.first.split(' ').last;
    var email = (await IdToken.validate(idToken))[kc.EMAIL];
    var ownerId = (await UsersCollection.getUser(email))[kc.ID].toString();
    var insertedTask = await TasksCollection.add(todo, ownerId);
    (insertedTask[kc.ERR] == null)
        ? request.response.statusCode = HttpStatus.created
        : request.response.statusCode = HttpStatus.internalServerError;
    request.response.headers.contentType = ContentType.json;
    request.response.write(insertedTask);
  }
}

import 'database.dart';

import '../model/user.dart';
import '../auth/id_token.dart';

import '../constants/keys.dart' as kc;
import '../constants/issuers.dart';

class UsersCollection {
  static Future<bool> createUser(Map<String, dynamic> tokenData) async {
    if (!tokenData.containsKey(kc.ACCESS_TOKEN)) return false;
    var user = User.fromTokenData(tokenData).toJson();
    // Apple only includes email in id_token on inital authentication
    if (tokenData[kc.ISSUER] == APPLE && tokenData[kc.EMAIL] == null) {
      user[kc.EMAIL] = await IdToken.validate(tokenData[kc.ID_TOKEN]);
    }
    if (user[kc.EMAIL] == null) return false;
    var usersCollection = await DB.usersCollection;
    await usersCollection.insert(user).catchError((_) async {
      // If we have a duplicate, update it with new data
      var dbUser = await usersCollection.findOne({kc.EMAIL: user[kc.EMAIL]});
      dbUser[kc.LAST_NAME] = user[kc.LAST_NAME] ?? dbUser[kc.LAST_NAME];
      dbUser[kc.FIRST_NAME] = user[kc.FIRST_NAME] ?? dbUser[kc.FIRST_NAME];
      dbUser[kc.NAME] = user[kc.NAME] ?? dbUser[kc.NAME];
      dbUser[kc.ROLES] = user[kc.ROLES];
      await usersCollection.save(dbUser);
    });
    await DB.close();
    return true;
  }

  static Future<List<Map<String, dynamic>>> users() async {
    var usersCollection = await DB.usersCollection;
    var userList = await usersCollection.find().toList();
    await DB.close();
    return userList;
  }

  static Future<Map<String, dynamic>> getUser(String email) async {
    var usersCollection = await DB.usersCollection;
    var user = await usersCollection.findOne({kc.EMAIL: email});
    await DB.close();
    return user;
  }

  static Future<void> delete({String email, String id}) async {
    if (email == null && id == null) return;
    var usersCollection = await DB.usersCollection;
    (email == null)
        ? await usersCollection.remove({kc.ID: id})
        : await usersCollection.remove({kc.EMAIL: email});
    await DB.close();
  }
}

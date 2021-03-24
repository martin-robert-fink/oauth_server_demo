import 'database.dart';

import '../constants/keys.dart' as kc;
import '../constants/values.dart' as vc;

class BlacklistCollection {
  static Future<Map<String, dynamic>> add(
      Map<String, dynamic> blacklistToken) async {
    var blacklistCollection = await DB.blacklistCollection;
    var insertedBlacklistToken =
        await blacklistCollection.insert(blacklistToken);
    await DB.close();
    return insertedBlacklistToken;
  }

  // if the token exists, send back true and then delete it
  static Future<bool> exists(Map<String, dynamic> blacklistToken) async {
    var blacklistCollection = await DB.blacklistCollection;
    var count = await blacklistCollection.count(blacklistToken);
    var exists = true;
    if (count == 0) exists = false;
    await DB.close();
    return exists;
  }

  // Remove a token
  static Future<void> remove(Map<String, dynamic> blacklistToken) async {
    var blacklistCollection = await DB.blacklistCollection;
    await blacklistCollection.remove(blacklistToken);
    await DB.close();
  }

  // Run this once a day to remove items from the blacklist that are more
  // than two months old
  static Future<void> cleanUp() async {
    var blacklistCollection = await DB.blacklistCollection;
    var blacklist = blacklistCollection.find();
    await blacklist.forEach((token) async {
      var issuedAt = DateTime.fromMillisecondsSinceEpoch(token[kc.IAT] * 1000);
      if (DateTime.now().difference(issuedAt).inDays > vc.TWO_MONTHS) {
        await blacklistCollection.remove(token);
      }
    });
  }
}

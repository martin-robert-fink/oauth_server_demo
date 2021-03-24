import 'package:mongo_dart/mongo_dart.dart';

import '../constants/database.dart' as dc;

class DB {
  static Db _db;

  static Future<void> _open() async {
    _db ??= Db(dc.DB_PATH);
    await _db.open();
  }

  static Future<void> close() async {
    await _db.close();
    _db = null;
  }

  static Future<DbCollection> get tasksCollection async {
    await DB._open();
    return _db.collection(dc.TASKS_COLLECTION);
  }

  static Future<DbCollection> get usersCollection async {
    await DB._open();
    return _db.collection(dc.USERS_COLLECTION);
  }

  static Future<DbCollection> get blacklistCollection async {
    await DB._open();
    return _db.collection(dc.BLACKLIST_COLLECTION);
  }
}

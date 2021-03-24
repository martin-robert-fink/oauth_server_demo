import 'database.dart';

import '../constants/keys.dart' as kc;

class TasksCollection {
  static Future<Map<String, dynamic>> add(
      Map<String, dynamic> task, String ownerId) async {
    var tasksCollection = await DB.tasksCollection;
    task.addAll({kc.OWNER_ID: ownerId});
    var insertedTask = await tasksCollection.insert(task);
    await DB.close();
    return insertedTask;
  }

  static Future<void> update(Map<String, dynamic> task, String ownerId) async {
    var tasksCollection = await DB.tasksCollection;
    task.addAll({kc.OWNER_ID: ownerId});
    await tasksCollection.findAndModify(
      query: {kc.ID: task[kc.ID], kc.OWNER_ID: ownerId},
      update: task,
    );
    await DB.close();
  }

  static Future<Map<String, dynamic>> delete(String id, String ownerId) async {
    var tasksCollection = await DB.tasksCollection;
    var result = await tasksCollection.remove({
      kc.ID: id,
      kc.OWNER_ID: ownerId,
    });
    await DB.close();
    return result;
  }

  static Future<Map<String, dynamic>> get(String id, String ownerId) async {
    var tasksCollection = await DB.tasksCollection;
    // Find the requested task, but remove the owner id field before returning
    var task = (await tasksCollection
        .findOne({kc.ID: id, kc.OWNER_ID: ownerId}))
      ..remove(kc.OWNER_ID);
    await DB.close();
    return task;
  }

  static Future<List<Map<String, dynamic>>> getAll(String ownerId) async {
    var tasksCollection = await DB.tasksCollection;
    // Get all tasks that belong to the owner, but remove the owner id
    // field before returning
    var tasks = await tasksCollection.find({kc.OWNER_ID: ownerId}).toList()
      ..map((task) => task..remove(kc.OWNER_ID)).toList();
    await DB.close();
    return tasks;
  }

  static Future<int> count(String ownerId) async {
    var tasksCollection = await DB.tasksCollection;
    var count = await tasksCollection.count({kc.OWNER_ID: ownerId});
    await DB.close();
    return count;
  }
}

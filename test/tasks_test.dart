import 'package:test/test.dart';
import 'package:uuid/uuid.dart';
import 'package:oauth_server_demo/database/tasks_collection.dart';

void main() {
  var task = Map<String, dynamic>.from({});

  setUp(() => task = {
        '_id': Uuid().v4(),
        'description': 'Task Name',
        'detail': 'Task Detail',
        'startDate': DateTime.now().toIso8601String(),
        'dueDate': DateTime.now().add(Duration(days: 7)).toIso8601String(),
        'complete': 0,
        'priority': 10,
      });

  group('Tasks Collection:', () {
    test('Task gets added/deleted successfully', () async {
      var id = Uuid().v4();
      var ownerId = Uuid().v4();
      task.addAll({'_id': id});
      var insertedTask = await TasksCollection.add(task, ownerId);
      expect(insertedTask['err'], null);
      var deletedTask = await TasksCollection.delete(id, ownerId);
      expect(deletedTask['err'], null);
    });

    test('Task gets updated successfully', () async {
      var id = Uuid().v4();
      var ownerId = Uuid().v4();
      task.addAll({'_id': id});
      var insertedTask = await TasksCollection.add(task, ownerId);
      expect(insertedTask['err'], null);
      task['priority'] = 50;
      await TasksCollection.update(task, ownerId);
      var fetchedTask = await TasksCollection.get(id, ownerId);
      expect(fetchedTask['priority'], 50);
      var deletedTask = await TasksCollection.delete(id, ownerId);
      expect(deletedTask['err'], null);
    });

    test('Get all/Count tasks owned by owner works', () async {
      var ownerId1 = Uuid().v4();
      for (var i = 0; i < 20; i++) {
        var id = Uuid().v4();
        task['_id'] = id;
        await TasksCollection.add(task, ownerId1);
      }
      var ownerId2 = Uuid().v4();
      for (var i = 0; i < 20; i++) {
        var id = Uuid().v4();
        task['_id'] = id;
        await TasksCollection.add(task, ownerId2);
      }
      var fetchedTasks = await TasksCollection.getAll(ownerId1);
      expect(fetchedTasks.length == 20, true);
      var count = await TasksCollection.count(ownerId2);
      expect(count, 20);
      for (var task in fetchedTasks) {
        await TasksCollection.delete(task['_id'], ownerId1);
      }
      fetchedTasks = await TasksCollection.getAll(ownerId2);
      for (var task in fetchedTasks) {
        await TasksCollection.delete(task['_id'], ownerId2);
      }
      count = await TasksCollection.count(ownerId1);
      expect(count, 0);
      count = await TasksCollection.count(ownerId2);
      expect(count, 0);
    });
  });
}

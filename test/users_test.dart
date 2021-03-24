import 'package:test/test.dart';
import 'package:oauth_server_demo/database/users_collection.dart';

void main() {
  var user = Map<String, dynamic>.from({});

  setUp(() => user.addAll({
        'firstName': 'Test',
        'lastName': 'User',
        'name': 'Test User',
        'email': 'test.user@test.com',
        'issuer': 'github',
        'access_token': 'fake access token', // Required for createUser
      }));

  group('Users database:', () {
    test('Attempt to create user without email fails', () async {
      user.remove('email');
      var created = await UsersCollection.createUser(user);
      expect(created, false);
    });

    test('Create/Delete new user succeeds', () async {
      await UsersCollection.createUser(user);
      var fetchedUser = await UsersCollection.getUser(user['email']);
      await UsersCollection.delete(email: user['email']);
      var found = await UsersCollection.getUser(user['email']);
      expect(fetchedUser['email'], user['email']);
      expect(null, found);
    });

    test('Adding duplicate user updates data', () async {
      var newFirstName = 'newFirstName';
      await UsersCollection.createUser(user);
      user['firstName'] = newFirstName;
      await UsersCollection.createUser(user);
      var fetchedUser = await UsersCollection.getUser(user['email']);
      expect(fetchedUser['firstName'], newFirstName);
      await UsersCollection.delete(email: user['email']);
    });
  });
}

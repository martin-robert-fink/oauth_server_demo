import 'package:test/test.dart';
import 'package:oauth_server_demo/database/blacklist_collection.dart';

void main() {
  var blacklistToken;

  setUp(() => blacklistToken = {
        'iss': 'facebook',
        'sub': 1,
        'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });
  group('Blacklist database:', () {
    test('Add/Remove Blacklisted token succeeds', () async {
      var addedToken = await BlacklistCollection.add(blacklistToken);
      expect((addedToken['err'] == null), true);
      blacklistToken.remove('iat');
      var exists = await BlacklistCollection.exists(blacklistToken);
      expect(exists, true);
      await BlacklistCollection.remove(blacklistToken);
      exists = await BlacklistCollection.exists(blacklistToken);
      expect(exists, false);
    });

    test('Cleanup blacklist collection succeeds', () async {
      // Create a bunch of tokens that are old enough to get removed
      // by the clean up.
      for (var i = 1; i <= 10; i++) {
        blacklistToken['sub'] = i;
        blacklistToken['iat'] = DateTime.now()
                .subtract(Duration(days: 61))
                .millisecondsSinceEpoch ~/
            1000;
        await BlacklistCollection.add(blacklistToken);
      }
      // Create a blacklist token that should NOT get removed during
      // cleanup
      blacklistToken['sub'] = 100;
      blacklistToken['iat'] = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await BlacklistCollection.add(blacklistToken);
      await BlacklistCollection.cleanUp();
      // The cleanup should NOT have removed the last item, but the
      // following call to exists will remove it.
      var exists = await BlacklistCollection.exists(blacklistToken);
      expect(exists, true);
      // Double-check to make sure that everything we added with an
      // old expiration did indeed get removed by the cleanup.
      for (var i = 1; i <= 10; i++) {
        blacklistToken['sub'] = i;
        var exists = await BlacklistCollection.exists(blacklistToken);
        expect(exists, false);
      }
    });
  });
}
